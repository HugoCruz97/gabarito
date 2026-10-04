require "test_helper"

class AnswerSheetsFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    subject = Subject.create!(name: "Matemática")
    @classroom = Classroom.create!(name: "3ª série")
    @ana = @classroom.students.create!(name: "Ana")
    @bia = @classroom.students.create!(name: "Bia")
    @exam = Exam.create!(title: "Meta", classrooms: [ @classroom ],
      exam_subjects_attributes: [ { subject_id: subject.id, questions_count: 2 } ])
    @exam.questions.each { |q| q.update!(correct_option: "A") }
  end

  test "envia várias fotos, cada uma com seu aluno, e agenda a leitura" do
    get new_exam_answer_sheet_path(@exam)
    assert_response :success
    assert_select "option", text: /Ana · 3ª série/

    assert_enqueued_jobs 2, only: ReadAnswerSheetJob do
      post exam_answer_sheets_path(@exam), params: { sheets: {
        "1" => { image: sheet_image, student_id: @ana.id },
        "2" => { image: sheet_image, student_id: "" }
      } }
    end

    assert_redirected_to exam_path(@exam, anchor: "cartoes")
    assert_equal [ @ana.id, nil ].sort_by(&:to_s), @exam.answer_sheets.pluck(:student_id).sort_by(&:to_s)
    follow_redirect!
    assert_select "#cartoes", text: /Na fila/
  end

  test "arquivo inválido não derruba o envio dos outros" do
    post exam_answer_sheets_path(@exam), params: { sheets: {
      "1" => { image: sheet_image, student_id: @ana.id },
      "2" => { image: fixture_file_upload("nao_e_imagem.txt", "text/plain"), student_id: @bia.id }
    } }

    assert_equal 1, @exam.answer_sheets.count
    assert_match "nao_e_imagem.txt", flash[:alert]
  end

  test "revisão corrige marcações, define o aluno e recalcula a nota" do
    sheet = @exam.answer_sheets.create!(image: sheet_image, status: :read)
    q1, q2 = @exam.questions.to_a
    sheet.answers.create!(exam_question: q1, marked_option: "B", status: "doubtful")
    sheet.answers.create!(exam_question: q2, marked_option: nil, multiple_marks: true, status: "multiple")
    sheet.grade!
    assert_equal 0, sheet.score

    get exam_answer_sheet_path(@exam, sheet)
    assert_response :success
    assert_select "a[href='#q1']"

    patch exam_answer_sheet_path(@exam, sheet), params: {
      answer_sheet: { student_id: @bia.id },
      answers: { q1.id => "A", q2.id => "A" }
    }

    sheet.reload
    assert sheet.reviewed?
    assert_equal @bia, sheet.student
    assert_equal 10, sheet.score
    assert_equal %w[manual manual], sheet.answers.pluck(:status)
  end

  test "salvar o gabarito recalcula as notas" do
    sheet = @exam.answer_sheets.create!(image: sheet_image, status: :read, student: @ana)
    @exam.questions.each { |q| sheet.answers.create!(exam_question: q, marked_option: "B", status: "ok") }
    sheet.grade!
    assert_equal 0, sheet.score

    patch exam_answer_key_path(@exam), params: { questions: @exam.questions.to_h { |q| [ q.id, { correct_option: "B", annulled: "0" } ] } }
    assert_equal 10, sheet.reload.score
  end
end
