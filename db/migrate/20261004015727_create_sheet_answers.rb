class CreateSheetAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :sheet_answers do |t|
      t.references :answer_sheet, null: false, foreign_key: { on_delete: :cascade }
      t.references :exam_question, null: false, foreign_key: { on_delete: :cascade }
      t.string :marked_option, limit: 1
      t.boolean :multiple_marks, null: false, default: false
      t.float :confidence

      t.timestamps
    end
    add_index :sheet_answers, [ :answer_sheet_id, :exam_question_id ], unique: true
  end
end
