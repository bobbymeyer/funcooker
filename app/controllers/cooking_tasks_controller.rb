class CookingTasksController < ApplicationController
  before_action :set_task

  def start
    @task.start!
    redirect_to @task.cooking_session
  end

  def complete
    @task.complete!
    redirect_to @task.cooking_session
  end

  def reopen
    @task.reopen!
    redirect_to @task.cooking_session
  end

  private
    def set_task
      @task = CookingTask.find(params[:id])
    end
end
