class Student < ApplicationRecord
  belongs_to :classroom
  has_many :answer_sheets, dependent: :restrict_with_error

  normalizes :registration_number, with: ->(value) { value.strip.presence }

  validates :name, presence: true
  validates :registration_number, uniqueness: true, allow_nil: true
end
