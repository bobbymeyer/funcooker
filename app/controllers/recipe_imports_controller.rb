class RecipeImportsController < ApplicationController
  def new
    @recipe_import = RecipeImport.new
  end

  def create
    @recipe_import = RecipeImport.new(recipe_import_params)

    if @recipe_import.save
      redirect_to @recipe_import
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @recipe_import = RecipeImport.find(params[:id])
    redirect_to @recipe_import.component if @recipe_import.succeeded?
  end

  private
    def recipe_import_params
      params.expect(recipe_import: %i[ source_url source_text ])
    end
end
