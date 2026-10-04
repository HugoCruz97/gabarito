class AnswerSheet < ApplicationRecord
  belongs_to :exam
  belongs_to :student, optional: true
  has_many :answers, class_name: "SheetAnswer", dependent: :destroy
  has_one_attached :image

  enum :status, {
    pending: "pending",       # imagem enviada, aguardando leitura
    processing: "processing", # leitura automática em andamento
    read: "read",             # lido, aguardando revisão
    reviewed: "reviewed",     # revisado e com nota final
    failed: "failed"          # não foi possível ler
  }, default: :pending

  # Questão anulada: todos ganham o ponto.
  # Marcação múltipla ou em branco: zero.
  def points_for(question, answer)
    return question.points_per_question if question.annulled?
    return 0 if answer.nil? || answer.multiple_marks? || answer.marked_option.blank?

    answer.marked_option == question.correct_option ? question.points_per_question : 0
  end

  # { ExamSubject => pontos }
  def score_by_subject
    answers_by_question = answers.index_by(&:exam_question_id)
    exam.questions.includes(:exam_subject).group_by(&:exam_subject).transform_values do |questions|
      questions.sum { |q| points_for(q, answers_by_question[q.id]) }
    end
  end

  def grade!
    update!(score: score_by_subject.values.sum)
  end
end
