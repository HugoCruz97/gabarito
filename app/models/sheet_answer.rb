class SheetAnswer < ApplicationRecord
  belongs_to :answer_sheet
  belongs_to :exam_question

  validates :marked_option, inclusion: { in: Exam::OPTIONS }, allow_nil: true
end
