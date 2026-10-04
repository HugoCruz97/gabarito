class ExamSubject < ApplicationRecord
  belongs_to :exam
  belongs_to :subject
  has_many :questions, -> { order(:number) }, class_name: "ExamQuestion", dependent: :destroy

  validates :questions_count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 200 }
  validates :points_per_question, numericality: { greater_than_or_equal_to: 0 }

  def total_points
    questions_count.to_i * points_per_question.to_d
  end
end
