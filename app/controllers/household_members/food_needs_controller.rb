class HouseholdMembers::FoodNeedsController < ApplicationController
  before_action :set_food_need, only: %i[ edit update destroy ]

  def create
    @household_member = HouseholdMember.find(params[:household_member_id])
    @food_need = @household_member.food_needs.new(food_need_params)

    if @food_need.save
      redirect_to edit_household_member_path(@household_member)
    else
      render "household_members/edit", status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @food_need.update(food_need_params)
      redirect_to edit_household_member_path(@household_member)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @food_need.destroy!
    redirect_to edit_household_member_path(@household_member)
  end

  private
    def set_food_need
      @food_need = FoodNeed.find(params[:id])
      @household_member = @food_need.household_member
    end

    def food_need_params
      params.expect(food_need: %i[ subject_key tier sentiment ])
    end
end
