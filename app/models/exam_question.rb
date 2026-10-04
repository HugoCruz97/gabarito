class ExamQuestion < ApplicationRecord
  belongs_to :exam
  belongs_to :exam_subject
  has_many :sheet_answers, dependent: :destroy

  validates :correct_option, :correct_option_es, inclusion: { in: Exam::OPTIONS }, allow_nil: true

  normalizes :correct_option, :correct_option_es, with: ->(value) { value.strip.upcase.presence }

  delegate :points_per_question, :foreign_language?, to: :exam_subject

  # Questão anulada não tem alternativa correta (todos ganham o ponto)
  before_validation do
    self.correct_option = nil if annulled?
    self.correct_option_es = nil if annulled_es?
  end

  # Em língua estrangeira, Inglês e Espanhol têm gabarito e anulação independentes.
  # Nas demais matérias a língua não importa (vale `correct_option`/`annulled`).
  # Retorna nil quando a questão é de língua e a língua do aluno é desconhecida.
  def correct_option_for(language)
    for_language(language, correct_option, correct_option_es)
  end

  def annulled_for?(language)
    for_language(language, annulled?, annulled_es?) || false
  end

  private

  def for_language(language, english, spanish)
    return english unless foreign_language?

    case language
    when "ingles" then english
    when "espanhol" then spanish
    end
  end
end
