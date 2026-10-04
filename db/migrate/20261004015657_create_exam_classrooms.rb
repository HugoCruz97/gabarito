class CreateExamClassrooms < ActiveRecord::Migration[8.1]
  def change
    create_table :exam_classrooms do |t|
      t.references :exam, null: false, foreign_key: { on_delete: :cascade }
      t.references :classroom, null: false, foreign_key: true

      t.timestamps
    end
    add_index :exam_classrooms, [ :exam_id, :classroom_id ], unique: true
  end
end
