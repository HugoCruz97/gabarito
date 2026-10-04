class StudentsController < ApplicationController
  before_action :set_student, only: %i[show edit update destroy]

  def index
    @classrooms = Classroom.order(:name)
    @students = Student.includes(:classroom).order(:name)
    @students = @students.where(classroom_id: params[:classroom_id]) if params[:classroom_id].present?
    @students = @students.where("students.name ILIKE :t OR students.registration_number ILIKE :t", t: "%#{Student.sanitize_sql_like(params[:q])}%") if params[:q].present?
  end

  def show
  end

  def new
    @student = Student.new(classroom_id: params[:classroom_id])
  end

  def edit
  end

  def create
    @student = Student.new(student_params)
    if @student.save
      if params[:add_another]
        redirect_to new_student_path(classroom_id: @student.classroom_id), notice: "#{@student.name} cadastrado."
      else
        redirect_to @student.classroom, notice: "Aluno cadastrado."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @student.update(student_params)
      redirect_to @student, notice: "Aluno atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @student.destroy
      redirect_to students_path, notice: "Aluno excluído.", status: :see_other
    else
      redirect_to @student, alert: @student.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_student
    @student = Student.find(params[:id])
  end

  def student_params
    params.expect(student: %i[name registration_number classroom_id])
  end
end
