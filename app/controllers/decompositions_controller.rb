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

  def confirm
    decomposition = Decomposition.find(params[:id])
    decomposition.confirm!
    redirect_to decomposition.component, notice: "Decomposed."
  rescue Decomposition::Error => e
    redirect_to decomposition.component, alert: e.message
  end

  def dismiss
    decomposition = Decomposition.find(params[:id])
    decomposition.dismiss!
    redirect_to decomposition.component, notice: "Left as it is."
  end

  def show
    @decomposition = Decomposition.find(params[:id])
    redirect_to @decomposition.component if @decomposition.succeeded? || @decomposition.declined? || @decomposition.awaiting?
  end
end
