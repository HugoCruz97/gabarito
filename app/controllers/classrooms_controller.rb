class ClassroomsController < ApplicationController
  before_action :set_classroom, only: %i[show edit update destroy]

  def index
    @classrooms = Classroom.order(school_year: :desc, name: :asc).includes(:students)
  end

  def show
  end

  def new
    @classroom = Classroom.new(school_year: Date.current.year)
  end

  def edit
  end

  def create
    @classroom = Classroom.new(classroom_params)
    if @classroom.save
      redirect_to @classroom, notice: "Turma criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @classroom.update(classroom_params)
      redirect_to @classroom, notice: "Turma atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @classroom.destroy
      redirect_to classrooms_path, notice: "Turma excluída.", status: :see_other
    else
      redirect_to @classroom, alert: @classroom.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def classroom_params
    params.expect(classroom: %i[name school_year])
  end
end
