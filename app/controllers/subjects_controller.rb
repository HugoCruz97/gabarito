class SubjectsController < ApplicationController
  before_action :set_subject, only: %i[edit update destroy]

  def index
    @subjects = Subject.order(:name)
    @subject = Subject.new
  end

  def new
    @subject = Subject.new
  end

  def edit
  end

  def create
    @subject = Subject.new(subject_params)
    if @subject.save
      redirect_to subjects_path, notice: "Matéria criada."
    else
      @subjects = Subject.order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @subject.update(subject_params)
      redirect_to subjects_path, notice: "Matéria atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @subject.destroy
      redirect_to subjects_path, notice: "Matéria excluída.", status: :see_other
    else
      redirect_to subjects_path, alert: @subject.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_subject
    @subject = Subject.find(params[:id])
  end

  def subject_params
    params.expect(subject: %i[name])
  end
end
