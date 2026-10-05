require "test_helper"

class AdaptedTest < ActiveSupport::TestCase
  setup do
    port = Subject.create!(name: "Português")
    lingua = Subject.create!(name: "Língua Estrangeira")
    @exam = Exam.create!(title: "Meta", adapted_answer_key: true, exam_subjects_attributes: [
      { subject_id: port.id, questions_count: 2, position: 0 },
      { subject_id: lingua.id, questions_count: 1, position: 1, foreign_language: true }
    ])
    @q1, @q2, @q3 = @exam.questions.to_a
    # normal: A, B / língua EN C, ES D — adaptado: C, D / língua EN A, ES B
    @q1.update!(correct_option: "A", correct_option_adapted: "C")
    @q2.update!(correct_option: "B", correct_option_adapted: "D")
    @q3.update!(correct_option: "C", correct_option_es: "D", correct_option_adapted: "A", correct_option_es_adapted: "B")

    classroom = Classroom.create!(name: "3ª série")
    @regular = classroom.students.create!(name: "Ana")
    @adapted = classroom.students.create!(name: "Bia", adapted: true)
  end

  def sheet(student, language, marks)
    s = @exam.answer_sheets.create!(student: student, language: language, image: sheet_image, status: :read)
    marks.each { |q, option| s.answers.create!(exam_question: q, marked_option: option) }
    s.tap(&:grade!)
  end

  test "aluno adaptado é corrigido pelo gabarito adaptado, inclusive na língua" do
    s = sheet(@adapted, "espanhol", @q1 => "C", @q2 => "D", @q3 => "B")
    assert s.adapted?
    assert_equal 20, s.score
  end

  test "aluno regular continua no gabarito normal" do
    s = sheet(@regular, "ingles", @q1 => "A", @q2 => "B", @q3 => "C")
    assert_not s.adapted?
    assert_equal 20, s.score
  end

  test "simulado sem gabarito adaptado corrige todos pelo normal" do
    @exam.update!(adapted_answer_key: false)
    s = sheet(@adapted, "ingles", @q1 => "A", @q2 => "B", @q3 => "C")
    assert_not s.adapted?
    assert_equal 20, s.score
  end

  test "anulação do gabarito adaptado é independente da normal" do
    @q1.update!(annulled_adapted: true, correct_option_adapted: "C")
    assert_nil @q1.reload.correct_option_adapted
    assert_equal "A", @q1.correct_option
    assert @q1.annulled_for?(nil, adapted: true)
    assert_not @q1.annulled_for?(nil)
  end

  test "marcar o aluno como adaptado recalcula as notas já lançadas" do
    s = sheet(@regular, "ingles", @q1 => "C", @q2 => "D", @q3 => "A")
    assert_equal 0, s.score
    @regular.update!(adapted: true)
    assert_equal 20, s.reload.score
  end

  test "progresso conta as duas versões quando há gabarito adaptado" do
    assert_equal 100, @exam.answer_key_progress
    @q3.update!(correct_option_es_adapted: nil)
    assert_equal 100, @exam.answer_key_progress(adapted: false)
    assert_equal 75, @exam.answer_key_progress(adapted: true) # 3 de 4
  end
end
