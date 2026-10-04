class Exam < ApplicationRecord
  OPTIONS = %w[A B C D E].freeze

  has_many :exam_classrooms, dependent: :destroy
  has_many :classrooms, through: :exam_classrooms
  has_many :exam_subjects, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :exam
  has_many :questions, -> { order(:number) }, class_name: "ExamQuestion", dependent: :destroy
  has_many :answer_sheets, dependent: :destroy

  accepts_nested_attributes_for :exam_subjects, allow_destroy: true,
    reject_if: ->(attrs) { attrs["id"].blank? && attrs["subject_id"].blank? }

  validates :title, presence: true
  validates :options_count, inclusion: { in: 2..OPTIONS.size }
  validate :must_have_subjects

  after_save :sync_questions!

  def options
    OPTIONS.first(options_count)
  end

  def total_questions
    exam_subjects.sum(&:questions_count)
  end

  def total_points
    exam_subjects.sum(&:total_points)
  end

  def answer_key_complete?
    questions.where(correct_option: nil, annulled: false).none?
  end

  private

  def must_have_subjects
    if exam_subjects.reject(&:marked_for_destruction?).empty?
      errors.add(:base, "Adicione pelo menos uma matéria ao simulado")
    end
  end

  # Mantém exam_questions numeradas de 1..N seguindo a ordem das matérias.
  # Preserva o gabarito já preenchido quando só muda a ordem ou a quantidade.
  def sync_questions!
    transaction do
      existing = questions.reload.group_by(&:exam_subject_id)
      # números temporários negativos para não violar o índice único durante a renumeração
      questions.update_all("number = -number")

      number = 0
      exam_subjects.reload.each do |exam_subject|
        current = (existing[exam_subject.id] || []).sort_by(&:number)
        current.drop(exam_subject.questions_count).each(&:destroy!)

        exam_subject.questions_count.times do |i|
          number += 1
          if (question = current[i])
            question.update_columns(number: number)
          else
            questions.create!(exam_subject: exam_subject, number: number)
          end
        end
      end
    end
  end
end
