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
  validate :at_most_one_foreign_language

  after_save :sync_questions!

  LANGUAGES = { "ingles" => "Inglês", "espanhol" => "Espanhol" }.freeze

  def options
    OPTIONS.first(options_count)
  end

  def total_questions
    exam_subjects.sum(&:questions_count)
  end

  def total_points
    exam_subjects.sum(&:total_points)
  end

  def foreign_language?
    exam_subjects.any?(&:foreign_language?)
  end

  def answer_key_complete?
    answer_key_progress == 100
  end

  # Percentual do gabarito preenchido. Questões de língua estrangeira têm dois gabaritos
  # (Inglês e Espanhol) e contam duas vezes; anuladas contam como preenchidas.
  def answer_key_progress
    foreign_ids = exam_subjects.select(&:foreign_language?).map(&:id)
    slots = questions.flat_map do |q|
      keys = [ [ q.correct_option, q.annulled? ] ]
      keys << [ q.correct_option_es, q.annulled_es? ] if foreign_ids.include?(q.exam_subject_id)
      keys.map { |key, annulled| key.present? || annulled }
    end
    return 0 if slots.empty?

    (slots.count(true) * 100.0 / slots.size).round
  end

  private

  def at_most_one_foreign_language
    if exam_subjects.reject(&:marked_for_destruction?).count(&:foreign_language?) > 1
      errors.add(:base, "Só uma matéria pode ser de língua estrangeira (Inglês/Espanhol)")
    end
  end

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
