require "test_helper"

class AnswerSheetTest < ActiveSupport::TestCase
  setup do
    math = Subject.create!(name: "Matemática")
    port = Subject.create!(name: "Português")
    @exam = Exam.create!(title: "Simulado", exam_subjects_attributes: [
      { subject_id: port.id, questions_count: 2, points_per_question: 1, position: 0 },
      { subject_id: math.id, questions_count: 2, points_per_question: 2.5, position: 1 }
    ])
    @q1, @q2, @q3, @q4 = @exam.questions.to_a
    @q1.update!(correct_option: "A")
    @q2.update!(correct_option: "B")
    @q3.update!(correct_option: "C")
    @q4.update!(correct_option: "D", annulled: true)

    classroom = Classroom.create!(name: "9º A")
    @sheet = @exam.answer_sheets.create!(student: classroom.students.create!(name: "Ana"))
  end

  def answer(question, option, multiple: false)
    @sheet.answers.create!(exam_question: question, marked_option: option, multiple_marks: multiple)
  end

  test "soma acertos, ignora erros e dá ponto da questão anulada" do
    answer(@q1, "A") # certo: 1
    answer(@q2, "C") # errado: 0
    answer(@q3, "C") # certo: 2,5
    answer(@q4, "A") # anulada: 2,5

    @sheet.grade!
    assert_equal 6, @sheet.score

    by_subject = @sheet.score_by_subject.transform_keys { |es| es.subject.name }
    assert_equal({ "Português" => 1, "Matemática" => 5 }, by_subject)
  end

  test "marcação múltipla ou em branco vale zero" do
    answer(@q1, "A", multiple: true)
    answer(@q3, nil)

    @sheet.grade!
    assert_equal 2.5, @sheet.score # só a anulada
  end
end
