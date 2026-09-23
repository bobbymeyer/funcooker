# A grocery receipt, from a photo or pasted text. The model reads it into
# lines; nothing reaches stock until the lines are confirmed.
class Receipt < ApplicationRecord
  class Error < StandardError; end

  IMAGE_TYPES = %w[ image/jpeg image/png image/webp ].freeze

  has_one_attached :photo
  has_many :lines, -> { order(:position) }, class_name: "ReceiptLine", dependent: :destroy, inverse_of: :receipt

  accepts_nested_attributes_for :lines

  enum :status, { pending: 0, processing: 1, parsed: 2, failed: 3, confirmed: 4 }, validate: true

  normalizes :source_text, with: ->(value) { value.strip.presence }

  validate :one_source
  validate :photo_is_an_image

  broadcasts_refreshes

  after_create_commit -> { ReceiptParseJob.perform_later(self) }

  def parse
    processing!
    reading = Extraction.read(text: source_text, image: photo_image, known: Ingredient.order(:name).pluck(:name))
    if reading[:lines].empty?
      raise Error, photo.attached? ?
        "No items found in the photo. If the receipt is legible, the model may not be seeing the image: #{Llm::VISION_HINT}" :
        "No items found on the receipt"
    end

    transaction do
      update!(store: reading[:store], purchased_on: reading[:purchased_on] || created_at.to_date)
      reading[:lines].each.with_index(1) do |line, position|
        lines.create!(
          position:, description: line[:description], ingredient_name: line[:item],
          quantity: line[:quantity], unit: line[:unit], included: line[:food],
          expires_on: (purchased_on + line[:shelf_life_days] if line[:shelf_life_days])
        )
      end
      parsed!
    end
  rescue Error, Llm::Error => e
    Rails.logger.error("Receipt #{id} failed: #{e.message}")
    update!(status: :failed, error: e.message)
  rescue => e
    update!(status: :failed, error: "Parsing failed (#{e.class})")
    raise
  end

  # Takes the lines as edited on the confirmation form, and stocks every one
  # still included, as a lot of its own. False, with errors on the lines,
  # when an included line is missing what stock needs.
  def confirm(attributes)
    raise Error, "Only a parsed receipt can be confirmed" unless parsed?

    assign_attributes(attributes)
    return false unless [ valid?, *lines.map { |line| line.valid?(:confirm) } ].all?

    transaction do
      lines.each(&:save!)
      lines.select(&:included?).each(&:stock!)
      update!(status: :confirmed, confirmed_at: Time.current)
    end
    true
  end

  private
    def one_source
      if photo.attached? && source_text
        errors.add(:base, "Give a photo or paste the receipt, not both")
      elsif !photo.attached? && !source_text
        errors.add(:base, "Give a photo or paste the receipt")
      end
    end

    def photo_is_an_image
      if photo.attached? && !photo.content_type.in?(IMAGE_TYPES)
        errors.add(:photo, "must be a JPEG, PNG or WebP image")
      end
    end

    def photo_image
      { data: photo.download, content_type: photo.content_type } if photo.attached?
    end
end
