class Components::IngredientLinesController < ApplicationController
  before_action :set_component, only: %i[ new create ]
  before_action :set_ingredient_line, only: %i[ edit update destroy ]

  def new
    @ingredient_line = @component.component_ingredients.new
  end

  def create
    @ingredient_line = @component.component_ingredients.new
    @ingredient_line.assign_attributes(ingredient_line_params)

    if @ingredient_line.save
      redirect_to @component
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @ingredient_line.update(ingredient_line_params)
      redirect_to @component
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @ingredient_line.destroy!
    redirect_to @component
  end

  private
    def set_component
      @component = Component.find(params[:component_id])
    end

    def set_ingredient_line
      @ingredient_line = ComponentIngredient.find(params[:id])
      @component = @ingredient_line.component
    end

    def ingredient_line_params
      params.expect(component_ingredient: %i[ ingredient_name ingredient_family_id quantity unit note step_id ])
    end
end
