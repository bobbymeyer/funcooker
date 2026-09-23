class IngredientFamiliesController < ApplicationController
  before_action :set_ingredient_family, only: %i[ edit update destroy ]

  def index
    @ingredient_families = IngredientFamily.includes(:ingredients).order(:name)
  end

  def new
    @ingredient_family = IngredientFamily.new
  end

  def create
    @ingredient_family = IngredientFamily.new(ingredient_family_params)

    if @ingredient_family.save
      redirect_to ingredient_families_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @ingredient_family.update(ingredient_family_params)
      redirect_to ingredient_families_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @ingredient_family.destroy
      redirect_to ingredient_families_path, notice: "Deleted #{@ingredient_family.name}."
    else
      redirect_to ingredient_families_path, alert: "#{@ingredient_family.name} was not deleted: #{@ingredient_family.errors.full_messages.to_sentence.downcase_first}"
    end
  end

  private
    def set_ingredient_family
      @ingredient_family = IngredientFamily.find(params[:id])
    end

    def ingredient_family_params
      params.expect(ingredient_family: %i[ name ])
    end
end
