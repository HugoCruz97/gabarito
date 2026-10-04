require "test_helper"

class ExamTest < ActiveSupport::TestCase
  setup do
    @math = Subject.create!(name: "Matemática")
    @port = Subject.create!(name: "Português")
  end

  def create_exam(subjects)
    Exam.create!(
      title: "Simulado",
      exam_subjects_attributes: subjects.each_with_index.map do |(subject, count, points), i|
        { subject_id: subject.id, questions_count: count, points_per_question: points, position: i }
      end
    )
  end

  test "exige pelo menos uma matéria" do
    exam = Exam.new(title: "Vazio")
    assert_not exam.valid?
    assert_includes exam.errors[:base], "Adicione pelo menos uma matéria ao simulado"
  end

  test "numera as questões em sequência seguindo a ordem das matérias" do
    exam = create_exam([ [ @port, 3, 1 ], [ @math, 2, 2 ] ])

    assert_equal [ 1, 2, 3, 4, 5 ], exam.questions.map(&:number)
    assert_equal [ "Português" ] * 3 + [ "Matemática" ] * 2, exam.questions.map { |q| q.exam_subject.subject.name }
    assert_equal 5, exam.total_questions
    assert_equal 7, exam.total_points
  end

  test "mantém o gabarito ao reordenar e ao mudar a quantidade" do
    exam = create_exam([ [ @port, 2, 1 ], [ @math, 2, 1 ] ])
    exam.questions.each { |q| q.update!(correct_option: q.exam_subject.subject == @math ? "C" : "A") }

    port, math = exam.exam_subjects.to_a
    exam.update!(exam_subjects_attributes: [
      { id: math.id, position: 0 },
      { id: port.id, position: 1, questions_count: 3 }
    ])

    assert_equal [ "C", "C", "A", "A", nil ], exam.questions.reload.map(&:correct_option)
    assert_equal [ 1, 2, 3, 4, 5 ], exam.questions.map(&:number)
  end

  test "remove questões ao diminuir a quantidade" do
    exam = create_exam([ [ @port, 5, 1 ] ])
    exam.update!(exam_subjects_attributes: [ { id: exam.exam_subjects.first.id, questions_count: 2 } ])
    assert_equal [ 1, 2 ], exam.questions.reload.map(&:number)
  end
end
