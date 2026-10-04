class CreateAnswerSheets < ActiveRecord::Migration[8.1]
  def change
    create_table :answer_sheets do |t|
      t.references :exam, null: false, foreign_key: { on_delete: :cascade }
      t.references :student, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.decimal :score, precision: 7, scale: 2

      t.timestamps
    end
  end
end
