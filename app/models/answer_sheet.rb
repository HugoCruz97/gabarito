class AnswerSheet < ApplicationRecord
  IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 20.megabytes

  belongs_to :exam
  belongs_to :student, optional: true
  has_many :answers, class_name: "SheetAnswer", dependent: :destroy
  has_one_attached :image    # foto/scan enviado
  has_one_attached :overlay  # imagem de conferência gerada pelo leitor

  # A página do simulado se atualiza sozinha enquanto os cartões são lidos
  broadcasts_refreshes_to :exam

  enum :status, {
    pending: "pending",       # imagem enviada, aguardando leitura
    processing: "processing", # leitura automática em andamento
    read: "read",             # lido pelo leitor (pode precisar de revisão)
    reviewed: "reviewed",     # conferido pela professora
    failed: "failed"          # não foi possível ler
  }, default: :pending

  validates :language, inclusion: { in: Exam::LANGUAGES.keys }, allow_nil: true
  validates :student_id, uniqueness: { scope: :exam_id, message: "já tem um cartão neste simulado" }, allow_nil: true
  validate :image_must_be_valid, on: :create

  scope :by_student_name, -> { left_joins(:student).order(Arel.sql("students.name NULLS LAST"), :created_at) }

  def self.template_key = Rails.configuration.x.omr.default_template

  # ---------- Leitura automática ----------

  def read_with_omr!(client = OmrClient.new)
    update!(status: :processing, error_message: nil)
    result = image.open do |file|
      client.read(file, filename: image.filename.to_s, questions: exam.total_questions,
        options: exam.options_count, template: self.class.template_key)
    end
    apply_reading!(result)
  rescue OmrClient::Error => e
    update!(status: :failed, error_message: e.message)
  end

  # Grava as marcações devolvidas pelo leitor e calcula a nota.
  # A questão N do cartão corresponde à questão N do simulado.
  def apply_reading!(result)
    readings = result.fetch("questions").index_by { |q| q["number"] }

    transaction do
      answers.delete_all
      exam.questions.each do |question|
        reading = readings[question.number] || { "status" => "blank" }
        multiple = reading["status"] == "multiple"
        answers.create!(
          exam_question: question,
          marked_option: (reading["answer"] unless multiple),
          multiple_marks: multiple,
          confidence: reading["confidence"],
          status: reading["status"]
        )
      end

      if (encoded = result["overlay_jpeg_base64"]).present?
        overlay.attach(io: StringIO.new(Base64.decode64(encoded)), filename: "conferencia-#{id}.jpg", content_type: "image/jpeg")
      end

      self.language = result["language"]
      self.status = :read
      self.read_at = Time.current
      self.error_message = nil
      grade!
    end
  end

  # ---------- Revisão ----------

  # Por que este cartão precisa do olho da professora (vazio = pode confiar na leitura)
  def review_reasons
    return [] unless read?

    reasons = []
    reasons << "aluno não informado" if student.nil?
    reasons << "língua (Inglês/Espanhol) não marcada" if language_missing?
    doubtful = answers.count { |a| a.status == "doubtful" }
    multiple = answers.count { |a| a.status == "multiple" }
    reasons << "#{doubtful} #{doubtful == 1 ? 'marcação duvidosa' : 'marcações duvidosas'}" if doubtful.positive?
    reasons << "#{multiple} com mais de uma alternativa" if multiple.positive?
    reasons
  end

  def needs_review?
    review_reasons.any?
  end

  def graded?
    read? || reviewed?
  end

  # ---------- Correção ----------

  # Prova adaptada: o aluno marcado como adaptado é corrigido pelo gabarito adaptado,
  # se o simulado tiver um (senão, pelo normal).
  def adapted?
    exam.adapted_answer_key? && student&.adapted? ? true : false
  end

  # Questão anulada: todos ganham o ponto.
  # Marcação múltipla ou em branco: zero.
  # Língua estrangeira: corrige pelo gabarito (e anulação) da língua marcada no cartão
  # (sem língua marcada não há como corrigir, então vale zero até a revisão).
  def points_for(question, answer)
    return question.points_per_question if question.annulled_for?(language, adapted: adapted?)
    return 0 if answer.nil? || answer.multiple_marks? || answer.marked_option.blank?

    expected = question.correct_option_for(language, adapted: adapted?)
    expected.present? && answer.marked_option == expected ? question.points_per_question : 0
  end

  def language_missing?
    language.nil? && exam.foreign_language?
  end

  # { ExamSubject => pontos }. Em listas, passe as questões já carregadas para não
  # repetir a consulta a cada cartão.
  def score_by_subject(questions = exam.questions.includes(:exam_subject))
    answers_by_question = answers.index_by(&:exam_question_id)
    questions.group_by(&:exam_subject).transform_values do |subject_questions|
      subject_questions.sum { |q| points_for(q, answers_by_question[q.id]) }
    end
  end

  def grade!
    update!(score: score_by_subject.values.sum)
  end

  private

  def image_must_be_valid
    if !image.attached?
      errors.add(:image, "é obrigatória")
    elsif !image.blob.content_type.in?(IMAGE_TYPES)
      errors.add(:image, "precisa ser uma foto JPG, PNG ou WEBP")
    elsif image.blob.byte_size > MAX_IMAGE_SIZE
      errors.add(:image, "é grande demais (máximo 20 MB)")
    end
  end
end
