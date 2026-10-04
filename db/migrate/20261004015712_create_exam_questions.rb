class CreateExamQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :exam_questions do |t|
      t.references :exam, null: false, foreign_key: { on_delete: :cascade }
      t.references :exam_subject, null: false, foreign_key: { on_delete: :cascade }
      t.integer :number, null: false
      t.string :correct_option, limit: 1
      t.boolean :annulled, null: false, default: false

      t.timestamps
    end
    add_index :exam_questions, [ :exam_id, :number ], unique: true
  end
end
