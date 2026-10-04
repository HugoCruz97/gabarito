class AnswerKeysController < ApplicationController
  before_action :set_exam

  def edit
    @questions_by_subject = @exam.questions.includes(exam_subject: :subject).group_by(&:exam_subject)
  end

  def update
    ExamQuestion.transaction do
      params.fetch(:questions, {}).each do |id, attrs|
        @exam.questions.find(id).update!(
          correct_option: attrs[:correct_option],
          annulled: attrs[:annulled] == "1"
        )
      end
    end
    redirect_to @exam, notice: "Gabarito salvo."
  end

  private

  def set_exam
    @exam = Exam.find(params[:exam_id])
  end
end
