class AddReadingDetailsToAnswerSheets < ActiveRecord::Migration[8.1]
  def change
    # Motivo da falha de leitura (ex.: "não encontrei o cartão na foto")
    add_column :answer_sheets, :error_message, :string
    add_column :answer_sheets, :read_at, :datetime

    # Como o leitor classificou a questão: ok | blank | multiple | doubtful
    # (manual = alterada pela professora na revisão)
    add_column :sheet_answers, :status, :string, null: false, default: "ok"

    # Um cartão por aluno em cada simulado
    add_index :answer_sheets, [ :exam_id, :student_id ], unique: true, where: "student_id IS NOT NULL"
  end
end
