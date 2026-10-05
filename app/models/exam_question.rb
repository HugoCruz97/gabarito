class ExamQuestion < ApplicationRecord
  # Cada questão pode ter até 4 gabaritos: normal ou adaptado × (Inglês | Espanhol).
  # Nas matérias comuns só existe o "Inglês"/padrão de cada versão.
  #   versão    língua     alternativa                 anulação
  KEY_FIELDS = {
    [ false, "ingles" ]   => %i[correct_option annulled],
    [ false, "espanhol" ] => %i[correct_option_es annulled_es],
    [ true,  "ingles" ]   => %i[correct_option_adapted annulled_adapted],
    [ true,  "espanhol" ] => %i[correct_option_es_adapted annulled_es_adapted]
  }.freeze
  OPTION_FIELDS = KEY_FIELDS.values.map(&:first).freeze

  belongs_to :exam
  belongs_to :exam_subject
  has_many :sheet_answers, dependent: :destroy

  validates(*OPTION_FIELDS, inclusion: { in: Exam::OPTIONS }, allow_nil: true)

  normalizes(*OPTION_FIELDS, with: ->(value) { value.strip.upcase.presence })

  delegate :points_per_question, :foreign_language?, to: :exam_subject

  # Questão anulada não tem alternativa correta (todos ganham o ponto)
  before_validation do
    KEY_FIELDS.each_value { |option, annulled| self[option] = nil if self[annulled] }
  end

  # Gabarito para a língua que o aluno marcou e para a versão da prova dele.
  # Retorna nil quando a questão é de língua e a língua do aluno é desconhecida.
  def correct_option_for(language, adapted: false)
    fields = key_fields(language, adapted)
    fields && self[fields.first]
  end

  def annulled_for?(language, adapted: false)
    fields = key_fields(language, adapted)
    fields ? self[fields.last] : false
  end

  # [campo da alternativa, campo da anulação] dos gabaritos que esta questão usa
  def answer_key_fields(adapted: false)
    languages = foreign_language? ? %w[ingles espanhol] : %w[ingles]
    languages.map { |language| KEY_FIELDS[[ adapted, language ]] }
  end

  private

  # Matérias comuns ignoram a língua; nas de língua estrangeira ela decide o gabarito
  def key_fields(language, adapted)
    language = "ingles" unless foreign_language?
    KEY_FIELDS[[ adapted, language ]]
  end
end
