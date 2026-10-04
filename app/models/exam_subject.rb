class ExamSubject < ApplicationRecord
  # Cada matéria do simulado vale 10 pontos, divididos igualmente entre as questões
  POINTS = 10

  belongs_to :exam
  belongs_to :subject
  has_many :questions, -> { order(:number) }, class_name: "ExamQuestion", dependent: :destroy

  validates :questions_count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 200 }

  # Valor exato (sem arredondar), para que as questões somem 10 mesmo quando a divisão
  # não é exata (ex.: 3 questões de 3,333… pontos). Arredondar só na hora de exibir.
  def points_per_question
    return 0 unless questions_count.to_i.positive?

    BigDecimal(POINTS) / questions_count
  end

  def total_points
    questions_count.to_i.positive? ? POINTS : 0
  end
end
