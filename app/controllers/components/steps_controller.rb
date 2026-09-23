class Components::StepsController < ApplicationController
  before_action :set_component, only: %i[ new create ]
  before_action :set_step, only: %i[ edit update destroy ]

  def new
    @step = @component.steps.new(position: @component.steps.maximum(:position).to_i + 1)
  end

  def create
    @step = @component.steps.new(position: @component.steps.maximum(:position).to_i + 1)
    @step.assign_attributes(step_params)

    if @step.save
      redirect_to @component
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @step.update(step_params)
      redirect_to @component
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @step.destroy!
    redirect_to @component
  end

  private
    def set_component
      @component = Component.find(params[:component_id])
    end

    def set_step
      @step = Step.find(params[:id])
      @component = @step.component
    end

    def step_params
      params.expect(step: %i[ position instructions phase mode duration_minutes ])
    end
end
