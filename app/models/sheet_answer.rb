class SheetAnswer < ApplicationRecord
  # ok: uma alternativa lida com segurança · blank: em branco · multiple: mais de uma
  # doubtful: marca fraca/rasura/X (o leitor sugere uma letra, mas pede conferência)
  # manual: definida pela professora na revisão
  STATUSES = %w[ok blank multiple doubtful manual].freeze

  belongs_to :answer_sheet
  belongs_to :exam_question

  validates :marked_option, inclusion: { in: Exam::OPTIONS }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  def needs_attention?
    status.in?(%w[doubtful multiple])
  end
end
