class DecompositionsController < ApplicationController
  def create
    component = Component.find(params[:component_id])
    decomposition = component.decompositions.new

    if decomposition.save
      redirect_to decomposition
    else
      redirect_to component, alert: decomposition.errors.full_messages.to_sentence
    end
  end

  def show
    @decomposition = Decomposition.find(params[:id])
    redirect_to @decomposition.component if @decomposition.succeeded?
  end
end
