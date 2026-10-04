class ExamClassroom < ApplicationRecord
  belongs_to :exam
  belongs_to :classroom
end
