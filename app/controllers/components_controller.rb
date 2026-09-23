class ComponentsController < ApplicationController
  before_action :set_component, only: %i[ show edit update destroy ]

  FILTERS = { "all" => "All", "dishes" => "Dishes", "parts" => "Parts of dishes" }.freeze

  def index
    @filter = FILTERS.key?(params[:show]) ? params[:show] : "all"
    @components = { "all" => Component.all, "dishes" => Component.dishes, "parts" => Component.parts }.fetch(@filter).order(:name)
  end

  def estimate_shelf_life
    component = Component.find(params[:id])
    component.estimate_shelf_life_later(overwrite: true)
    redirect_to component, notice: "Estimating how long it keeps. This page updates when it is done."
  end

  def estimate_shelf_lives
    missing = Component.where(shelf_life_days: nil).to_a
    missing.each(&:estimate_shelf_life_later)
    redirect_to components_path, notice: "Estimating #{helpers.pluralize(missing.size, "shelf life", plural: "shelf lives")}."
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
