require "test_helper"

class ExamTest < ActiveSupport::TestCase
  setup do
    @math = Subject.create!(name: "Matemática")
    @port = Subject.create!(name: "Português")
  end

  def create_exam(subjects)
    Exam.create!(
      title: "Simulado",
      exam_subjects_attributes: subjects.each_with_index.map do |(subject, count), i|
        { subject_id: subject.id, questions_count: count, position: i }
      end
    )
  end

  test "exige pelo menos uma matéria" do
    exam = Exam.new(title: "Vazio")
    assert_not exam.valid?
    assert_includes exam.errors[:base], "Adicione pelo menos uma matéria ao simulado"
  end

  test "numera as questões em sequência seguindo a ordem das matérias" do
    exam = create_exam([ [ @port, 3 ], [ @math, 2 ] ])

    assert_equal [ 1, 2, 3, 4, 5 ], exam.questions.map(&:number)
    assert_equal [ "Português" ] * 3 + [ "Matemática" ] * 2, exam.questions.map { |q| q.exam_subject.subject.name }
    assert_equal 5, exam.total_questions
    assert_equal 20, exam.total_points # 10 por matéria
  end

  test "cada matéria vale 10 pontos divididos igualmente entre as questões" do
    exam = create_exam([ [ @port, 8 ], [ @math, 3 ] ])
    port, math = exam.exam_subjects.to_a

    assert_equal BigDecimal("1.25"), port.points_per_question
    assert_equal 10, port.total_points
    # 10 ÷ 3 não é exato, mas as 3 questões precisam somar 10
    assert_equal 10, (math.points_per_question * 3).round(2)
  end

  test "mantém o gabarito ao reordenar e ao mudar a quantidade" do
    exam = create_exam([ [ @port, 2 ], [ @math, 2 ] ])
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
    exam = create_exam([ [ @port, 5 ] ])
    exam.update!(exam_subjects_attributes: [ { id: exam.exam_subjects.first.id, questions_count: 2 } ])
    assert_equal [ 1, 2 ], exam.questions.reload.map(&:number)
  end
end
