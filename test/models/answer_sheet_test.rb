require "test_helper"

class AnswerSheetTest < ActiveSupport::TestCase
  setup do
    math = Subject.create!(name: "Matemática")
    port = Subject.create!(name: "Português")
    @exam = Exam.create!(title: "Simulado", exam_subjects_attributes: [
      { subject_id: port.id, questions_count: 2, position: 0 },
      { subject_id: math.id, questions_count: 2, position: 1 }
    ])
    @q1, @q2, @q3, @q4 = @exam.questions.to_a
    @q1.update!(correct_option: "A")
    @q2.update!(correct_option: "B")
    @q3.update!(correct_option: "C")
    @q4.update!(correct_option: "D", annulled: true)

    classroom = Classroom.create!(name: "9º A")
    @sheet = @exam.answer_sheets.create!(student: classroom.students.create!(name: "Ana"), image: sheet_image)
  end

  def answer(question, option, multiple: false)
    @sheet.answers.create!(exam_question: question, marked_option: option, multiple_marks: multiple)
  end

  # 2 questões por matéria → cada questão vale 10 ÷ 2 = 5 pontos
  test "soma acertos, ignora erros e dá ponto da questão anulada" do
    answer(@q1, "A") # Português, certo: 5
    answer(@q2, "C") # Português, errado: 0
    answer(@q3, "C") # Matemática, certo: 5
    answer(@q4, "A") # Matemática, anulada: 5

    @sheet.grade!
    assert_equal 15, @sheet.score

    by_subject = @sheet.score_by_subject.transform_keys { |es| es.subject.name }
    assert_equal({ "Português" => 5, "Matemática" => 10 }, by_subject)
  end

  test "marcação múltipla ou em branco vale zero" do
    answer(@q1, "A", multiple: true)
    answer(@q3, nil)

    @sheet.grade!
    assert_equal 5, @sheet.score # só a anulada
  end

  test "nota máxima de uma matéria é 10 mesmo com divisão não exata" do
    subject = Subject.create!(name: "Física")
    exam = Exam.create!(title: "Três questões", exam_subjects_attributes: [ { subject_id: subject.id, questions_count: 3 } ])
    exam.questions.each { |q| q.update!(correct_option: "A") }
    sheet = exam.answer_sheets.create!(image: sheet_image)
    exam.questions.each { |q| sheet.answers.create!(exam_question: q, marked_option: "A") }

    sheet.grade!
    assert_equal 10, sheet.score
  end
end
