class ComponentsController < ApplicationController
  before_action :set_component, only: %i[ show edit update destroy ]

  def index
    @components = Component.order(:name)
  end

  def show
  end

  def new
    @component = Component.new
  end

  def create
    @component = Component.new(component_params)

    if @component.save
      redirect_to @component
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @component.update(component_params)
      redirect_to @component
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @component.destroy
      redirect_to components_path, notice: "Deleted #{@component.name}."
    else
      redirect_to @component, alert: @component.errors.full_messages.to_sentence
    end
  end

  private
    def set_component
      @component = Component.find(params[:id])
    end

    def component_params
      params.expect(component: %i[ name description source_url shelf_life_days ])
    end
end
