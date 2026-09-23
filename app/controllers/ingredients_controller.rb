class IngredientsController < ApplicationController
  before_action :set_ingredient, only: %i[ edit update destroy ]

  def index
    @ingredients = Ingredient.includes(:ingredient_family).order(:name)
  end

  def new
    @ingredient = Ingredient.new
  end

  def create
    @ingredient = Ingredient.new(ingredient_params)

    if @ingredient.save
      redirect_to ingredients_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @ingredient.update(ingredient_params)
      redirect_to ingredients_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @ingredient.destroy
      redirect_to ingredients_path, notice: "Deleted #{@ingredient.name}."
    else
      redirect_to ingredients_path, alert: "#{@ingredient.name} was not deleted: #{@ingredient.errors.full_messages.to_sentence.downcase_first}"
    end
  end

  private
    def set_ingredient
      @ingredient = Ingredient.find(params[:id])
    end

    def ingredient_params
      params.expect(ingredient: %i[ name category default_unit pack_size ingredient_family_id ])
    end
end
