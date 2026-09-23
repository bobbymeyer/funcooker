class DecompositionJob < ApplicationJob
  def perform(decomposition)
    decomposition.process
  end
end
