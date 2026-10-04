class Classroom < ApplicationRecord
  has_many :students, -> { order(:name) }, dependent: :restrict_with_error
  has_many :exam_classrooms, dependent: :restrict_with_error
  has_many :exams, through: :exam_classrooms

  validates :name, presence: true

  def display_name
    school_year ? "#{name} (#{school_year})" : name
  end
end
