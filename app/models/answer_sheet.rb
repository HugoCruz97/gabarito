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

  validates :language, inclusion: { in: Exam::LANGUAGES.keys }, allow_nil: true

  # Questão anulada: todos ganham o ponto.
  # Marcação múltipla ou em branco: zero.
  # Língua estrangeira: corrige pelo gabarito (e anulação) da língua marcada no cartão
  # (sem língua marcada não há como corrigir, então vale zero até a revisão).
  def points_for(question, answer)
    return question.points_per_question if question.annulled_for?(language)
    return 0 if answer.nil? || answer.multiple_marks? || answer.marked_option.blank?

    expected = question.correct_option_for(language)
    expected.present? && answer.marked_option == expected ? question.points_per_question : 0
  end

  def language_missing?
    language.nil? && exam.foreign_language?
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
