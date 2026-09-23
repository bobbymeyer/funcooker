class Components::PartsController < ApplicationController
  before_action :set_component, only: %i[ new create ]
  before_action :set_part, only: %i[ edit update destroy ]

  def new
    @part = @component.child_parts.new(quantity: 1, unit: "serving")
  end

  def create
    @part = @component.child_parts.new(quantity: 1, unit: "serving")
    @part.assign_attributes(part_params)

    if @part.save
      redirect_to @component
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @part.update(part_params)
      redirect_to @component
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @part.destroy!
    redirect_to @component
  end

  private
    def set_component
      @component = Component.find(params[:component_id])
    end

    def set_part
      @part = ComponentPart.find(params[:id])
      @component = @part.parent
    end

    def part_params
      params.expect(component_part: %i[ child_id quantity unit step_id ])
    end
end
