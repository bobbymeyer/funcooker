# The batches of a prep plan form: each ticked row's component, servings and
# servings to freeze.
module PrepBatchParams
  private
    def prep_batches
      params.fetch(:batches, {}).values.filter_map do |batch|
        next unless batch[:include] == "1"

        servings = batch[:servings].to_d rescue 0
        frozen_servings = batch[:frozen_servings].to_d rescue 0
        component = Component.find_by(id: batch[:component_id])
        { component:, servings:, frozen_servings: } if component && servings.positive?
      end
    end
end
