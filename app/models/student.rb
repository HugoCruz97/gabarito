class Student < ApplicationRecord
  belongs_to :classroom
  has_many :answer_sheets, dependent: :restrict_with_error

  normalizes :registration_number, with: ->(value) { value.strip.presence }

  validates :name, presence: true
  validates :registration_number, uniqueness: true, allow_nil: true

  # Passou a fazer (ou deixou de fazer) prova adaptada: as notas já lançadas mudam de gabarito
  after_update_commit :regrade_answer_sheets, if: :saved_change_to_adapted?

  private

  def regrade_answer_sheets
    answer_sheets.where(status: %w[read reviewed]).includes(:answers, :exam).find_each(&:grade!)
  end
end
