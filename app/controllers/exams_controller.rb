class ExamsController < ApplicationController
  before_action :set_exam, only: %i[show edit update destroy]
  before_action :load_form_options, only: %i[new edit create update]

  def index
    @exams = Exam.includes(:classrooms, :questions, exam_subjects: :subject).order(applied_on: :desc, created_at: :desc)
  end

  def show
  end

  def new
    @exam = Exam.new(applied_on: Date.current)
    @exam.exam_subjects.build
  end

  def edit
  end

  def create
    @exam = Exam.new(exam_params)
    if @exam.save
      redirect_to edit_exam_answer_key_path(@exam), notice: "Simulado criado. Agora preencha o gabarito."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @exam.update(exam_params)
      redirect_to @exam, notice: "Simulado atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @exam.destroy
    redirect_to exams_path, notice: "Simulado excluído.", status: :see_other
  end

  private

  def set_exam
    @exam = Exam.find(params[:id])
  end

  def load_form_options
    @subjects = Subject.order(:name)
    @classrooms = Classroom.order(school_year: :desc, name: :asc)
  end

  def exam_params
    params.expect(exam: [
      :title, :applied_on, :options_count, classroom_ids: [],
      exam_subjects_attributes: [ [ :id, :subject_id, :questions_count, :points_per_question, :position, :foreign_language, :_destroy ] ]
    ])
  end
end
