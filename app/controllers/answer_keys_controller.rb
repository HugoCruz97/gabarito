class AnswerKeysController < ApplicationController
  before_action :set_exam

  def edit
    @questions_by_subject = @exam.questions.includes(exam_subject: :subject).group_by(&:exam_subject)
  end

  def update
    ExamQuestion.transaction do
      params.fetch(:questions, {}).each do |id, attrs|
        question = @exam.questions.find(id)
        changes = { correct_option: attrs[:correct_option], annulled: attrs[:annulled] == "1" }
        if question.foreign_language?
          changes.merge!(correct_option_es: attrs[:correct_option_es], annulled_es: attrs[:annulled_es] == "1")
        end
        question.update!(changes)
      end
    end
    redirect_to @exam, notice: "Gabarito salvo."
  end

  private

  def set_exam
    @exam = Exam.find(params[:exam_id])
  end
end
