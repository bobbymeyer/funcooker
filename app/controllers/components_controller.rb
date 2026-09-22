class ComponentsController < ApplicationController
  def index
    @components = Component.order(:name)
  end

  def show
    @component = Component.find(params[:id])
  end
end
