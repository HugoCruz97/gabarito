class Subject < ApplicationRecord
  has_many :exam_subjects, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
