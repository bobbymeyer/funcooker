# Fills meal slots with dishes, greedily, one slot at a time in date order,
# for the people who eat by default. Dishes that violate any of their
# restrictions are never candidates. The rest are scored:
#
#   stock    how much of the dish is on hand, 0-1                    x 3
#   expiry   on-hand stock it uses that expires within 4 days,
#            sooner counts more, each lot counted once per plan      x 2
#   share    ingredients shared with dishes planned within 3 days    x 1
#   repeat   the same dish within 7 days, closer counts more         x -4
#   likes    +1 per member who likes something in it,
#            -1 per member who dislikes something in it              x 1
#
# Ties go to the dish name, so a plan is repeatable. Derived entries are never
# repaired: planning or re-deriving deletes the planned, derived entries in
# the slots it covers and fills them again. Entries added by hand are kept.
class Schedule::Planner
  WEIGHTS = { stock: 3, expiry: 2, share: 1, repeat: -4, likes: 1 }.freeze
  EXPIRY_HORIZON = 4
  SHARE_WINDOW = 3
  REPEAT_WINDOW = 7

  OnHand = Struct.new(:ingredient_ids, :component_ids)

  def self.derive(from:, days:, meal_slots:)
    slots = (from...(from + days)).to_a.product(meal_slots.map(&:to_s))
    new.replace(slots)
  end

  # After a disruption: every planned, derived entry from this date on is
  # planned again, now.
  def self.rederive(from:)
    entries = ScheduleEntry.derived.planned.where(served_on: from..)
    new.replace(entries.map { |entry| [ entry.served_on, entry.meal_slot ] })
  end

  def initialize(members: HouseholdMember.by_default.includes(food_needs: :subject).to_a)
    @members = members
    @likes = members.flat_map { |member| member.food_needs.select(&:preference?) }
  end

  def replace(slots)
    ScheduleEntry.transaction do
      slots.each { |date, slot| ScheduleEntry.derived.planned.where(served_on: date, meal_slot: slot).destroy_all }
      fill(slots)
    end
  end

  def fill(slots)
    candidates = Component.schedulable_for(@members).sort_by { |dish| [ dish.name.downcase, dish.id ] }.to_h { |dish| [ dish, DishContents.new(dish) ] }
    return [] if candidates.empty?

    lots = StockItem.on_hand.to_a
    on_hand = OnHand.new(ids_of(lots, Ingredient), ids_of(lots, Component))
    expiring = lots.select { |lot| lot.expires_on && lot.expires_on <= Date.current + EXPIRY_HORIZON }
    claimed = Set.new

    slots.uniq.sort_by { |date, slot| [ date, ScheduleEntry.meal_slots.fetch(slot.to_s) ] }.filter_map do |date, slot|
      next if ScheduleEntry.active.exists?(served_on: date, meal_slot: slot)

      nearby = ScheduleEntry.active.includes(:dish).where(served_on: (date - REPEAT_WINDOW)..(date + REPEAT_WINDOW)).to_a
      # max_by keeps the first of equal scores, and candidates are in name order.
      dish, contents = candidates.max_by do |candidate, contents|
        score(candidate, contents, date, on_hand, expiring - claimed.to_a, nearby, candidates)
      end

      claimed.merge(expiring.select { |lot| contents.draws_on?(lot) })
      ScheduleEntry.create!(served_on: date, meal_slot: slot, dish:, origin: :derived, diners: @members)
    end
  end

  def score(dish, contents, date, on_hand, expiring, nearby, candidates)
    stock = contents.coverage(on_hand)

    expiry = expiring.select { |lot| contents.draws_on?(lot) }.sum do |lot|
      1.0 / ((lot.expires_on - date).to_i.clamp(0, EXPIRY_HORIZON) + 1)
    end

    neighbours = nearby.select { |entry| (entry.served_on - date).abs <= SHARE_WINDOW && entry.dish != dish }
    shared = neighbours.flat_map { |entry| (candidates[entry.dish] || DishContents.new(entry.dish)).ingredient_ids.to_a }.to_set
    share = contents.ingredient_ids.empty? ? 0 : (contents.ingredient_ids & shared).size.fdiv(contents.ingredient_ids.size)

    repeat = nearby.select { |entry| entry.dish == dish }.sum { |entry| 1 - (entry.served_on - date).abs.fdiv(REPEAT_WINDOW) }

    likes = @likes.select { |need| contents.include?(need.subject) }.sum { |need| need.likes? ? 1 : -1 }

    WEIGHTS[:stock] * stock + WEIGHTS[:expiry] * expiry + WEIGHTS[:share] * share + WEIGHTS[:repeat] * repeat + WEIGHTS[:likes] * likes
  end

  private
    def ids_of(lots, type)
      lots.select { |lot| lot.stockable_type == type.name }.map(&:stockable_id).to_set
    end
end
