# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_04_015735) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "answer_sheets", force: :cascade do |t|
    t.bigint "exam_id", null: false
    t.bigint "student_id"
    t.string "status", default: "pending", null: false
    t.decimal "score", precision: 7, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_id"], name: "index_answer_sheets_on_exam_id"
    t.index ["student_id"], name: "index_answer_sheets_on_student_id"
  end

  create_table "classrooms", force: :cascade do |t|
    t.string "name", null: false
    t.integer "school_year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "exam_classrooms", force: :cascade do |t|
    t.bigint "exam_id", null: false
    t.bigint "classroom_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_exam_classrooms_on_classroom_id"
    t.index ["exam_id", "classroom_id"], name: "index_exam_classrooms_on_exam_id_and_classroom_id", unique: true
    t.index ["exam_id"], name: "index_exam_classrooms_on_exam_id"
  end

  create_table "exam_questions", force: :cascade do |t|
    t.bigint "exam_id", null: false
    t.bigint "exam_subject_id", null: false
    t.integer "number", null: false
    t.string "correct_option", limit: 1
    t.boolean "annulled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_id", "number"], name: "index_exam_questions_on_exam_id_and_number", unique: true
    t.index ["exam_id"], name: "index_exam_questions_on_exam_id"
    t.index ["exam_subject_id"], name: "index_exam_questions_on_exam_subject_id"
  end

  create_table "exam_subjects", force: :cascade do |t|
    t.bigint "exam_id", null: false
    t.bigint "subject_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "questions_count", null: false
    t.decimal "points_per_question", precision: 6, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_id"], name: "index_exam_subjects_on_exam_id"
    t.index ["subject_id"], name: "index_exam_subjects_on_subject_id"
  end

  create_table "exams", force: :cascade do |t|
    t.string "title", null: false
    t.date "applied_on"
    t.integer "options_count", default: 5, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sheet_answers", force: :cascade do |t|
    t.bigint "answer_sheet_id", null: false
    t.bigint "exam_question_id", null: false
    t.string "marked_option", limit: 1
    t.boolean "multiple_marks", default: false, null: false
    t.float "confidence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["answer_sheet_id", "exam_question_id"], name: "index_sheet_answers_on_answer_sheet_id_and_exam_question_id", unique: true
    t.index ["answer_sheet_id"], name: "index_sheet_answers_on_answer_sheet_id"
    t.index ["exam_question_id"], name: "index_sheet_answers_on_exam_question_id"
  end

  create_table "students", force: :cascade do |t|
    t.string "name", null: false
    t.string "registration_number"
    t.bigint "classroom_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_students_on_classroom_id"
    t.index ["registration_number"], name: "index_students_on_registration_number", unique: true
  end

  create_table "subjects", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_subjects_on_name", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "answer_sheets", "exams", on_delete: :cascade
  add_foreign_key "answer_sheets", "students"
  add_foreign_key "exam_classrooms", "classrooms"
  add_foreign_key "exam_classrooms", "exams", on_delete: :cascade
  add_foreign_key "exam_questions", "exam_subjects", on_delete: :cascade
  add_foreign_key "exam_questions", "exams", on_delete: :cascade
  add_foreign_key "exam_subjects", "exams", on_delete: :cascade
  add_foreign_key "exam_subjects", "subjects"
  add_foreign_key "sheet_answers", "answer_sheets", on_delete: :cascade
  add_foreign_key "sheet_answers", "exam_questions", on_delete: :cascade
  add_foreign_key "students", "classrooms"
end
