class AnswerKeysController < ApplicationController
  before_action :set_exam
  before_action :set_version

  def edit
    @questions_by_subject = @exam.questions.includes(exam_subject: :subject).group_by(&:exam_subject)
  end

  # Grava só a versão em edição (normal ou adaptada); a outra fica como está
  def update
    ExamQuestion.transaction do
      params.fetch(:questions, {}).each do |id, attrs|
        question = @exam.questions.find(id)
        changes = {}
        question.answer_key_fields(adapted: @adapted).each do |option, annulled|
          changes[option] = attrs[option]
          changes[annulled] = attrs[annulled] == "1"
        end
        question.update!(changes)
      end
    end
    @exam.regrade_answer_sheets!
    redirect_to @exam, notice: @adapted ? "Gabarito adaptado salvo." : "Gabarito salvo."
  end

  private

  def set_exam
    @exam = Exam.find(params[:exam_id])
  end

  def set_version
    @adapted = @exam.adapted_answer_key? && params[:versao] == "adaptada"
  end
end
