class HouseholdMembersController < ApplicationController
  before_action :set_household_member, only: %i[ edit update destroy ]

  def index
    @household_members = HouseholdMember.includes(food_needs: :subject).order(:name)
  end

  def new
    @household_member = HouseholdMember.new
  end

  def create
    @household_member = HouseholdMember.new(household_member_params)

    if @household_member.save
      redirect_to edit_household_member_path(@household_member)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @food_need = @household_member.food_needs.new
  end

  def update
    if @household_member.update(household_member_params)
      redirect_to household_members_path
    else
      @food_need = @household_member.food_needs.new
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @household_member.destroy!
    redirect_to household_members_path, notice: "Removed #{@household_member.name}."
  end

  private
    def set_household_member
      @household_member = HouseholdMember.find(params[:id])
    end

    def household_member_params
      params.expect(household_member: %i[ name ])
    end
end
