class ExamQuestion < ApplicationRecord
  belongs_to :exam
  belongs_to :exam_subject
  has_many :sheet_answers, dependent: :destroy

  validates :correct_option, inclusion: { in: Exam::OPTIONS }, allow_nil: true

  normalizes :correct_option, with: ->(value) { value.strip.upcase.presence }

  delegate :points_per_question, to: :exam_subject
end
