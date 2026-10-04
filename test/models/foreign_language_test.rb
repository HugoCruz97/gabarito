require "test_helper"

class ForeignLanguageTest < ActiveSupport::TestCase
  setup do
    lingua = Subject.create!(name: "Língua Estrangeira")
    port = Subject.create!(name: "Português")
    @exam = Exam.create!(title: "Meta Simulado", exam_subjects_attributes: [
      { subject_id: lingua.id, questions_count: 2, points_per_question: 1, position: 0, foreign_language: true },
      { subject_id: port.id, questions_count: 1, points_per_question: 1, position: 1 }
    ])
    @q1, @q2, @q3 = @exam.questions.to_a
    @q1.update!(correct_option: "A", correct_option_es: "B")
    @q2.update!(correct_option: "C", correct_option_es: "C")
    @q3.update!(correct_option: "D")

    @student = Classroom.create!(name: "3ª série").students.create!(name: "Bia")
  end

  def sheet(language, answers)
    s = @exam.answer_sheets.create!(student: @student, language: language)
    answers.each { |q, option| s.answers.create!(exam_question: q, marked_option: option) }
    s
  end

  test "corrige as questões de língua pelo gabarito da língua marcada" do
    assert_equal 3, sheet("ingles", @q1 => "A", @q2 => "C", @q3 => "D").tap(&:grade!).score
    assert_equal 3, sheet("espanhol", @q1 => "B", @q2 => "C", @q3 => "D").tap(&:grade!).score
    # resposta de inglês num cartão de espanhol não vale
    assert_equal 2, sheet("espanhol", @q1 => "A", @q2 => "C", @q3 => "D").tap(&:grade!).score
  end

  test "sem língua marcada as questões de língua valem zero e o cartão pede revisão" do
    s = sheet(nil, @q1 => "A", @q2 => "C", @q3 => "D")
    s.grade!
    assert_equal 1, s.score
    assert s.language_missing?
  end

  test "matérias comuns não dependem da língua" do
    assert_equal "D", @q3.correct_option_for(nil)
    assert_equal "D", @q3.correct_option_for("espanhol")
  end

  test "anulação é independente em cada língua" do
    @q1.update!(annulled: true) # só o Inglês

    assert_equal 3, sheet("ingles", @q1 => "E", @q2 => "C", @q3 => "D").tap(&:grade!).score   # ganha o ponto anulado
    assert_equal 2, sheet("espanhol", @q1 => "E", @q2 => "C", @q3 => "D").tap(&:grade!).score # Espanhol não foi anulada
    assert_equal 3, sheet("espanhol", @q1 => "B", @q2 => "C", @q3 => "D").tap(&:grade!).score

    @q1.update!(annulled: false, annulled_es: true) # só o Espanhol
    assert_equal 3, sheet("espanhol", @q1 => "E", @q2 => "C", @q3 => "D").tap(&:grade!).score
    assert_equal 2, sheet("ingles", @q1 => "E", @q2 => "C", @q3 => "D").tap(&:grade!).score
  end

  test "questão anulada não guarda alternativa correta, em cada língua separadamente" do
    @q1.update!(annulled: true, correct_option: "A")
    assert_nil @q1.reload.correct_option
    assert_equal "B", @q1.correct_option_es # Espanhol continua com gabarito

    @q1.update!(annulled_es: true, correct_option_es: "B")
    assert_nil @q1.reload.correct_option_es
  end

  test "progresso do gabarito conta os dois gabaritos de língua" do
    assert_equal 100, @exam.answer_key_progress
    @q1.update!(correct_option_es: nil)
    assert_equal 80, @exam.reload.answer_key_progress # 4 de 5 preenchidos
    @q1.update!(annulled: true) # anular o Inglês não completa o Espanhol
    assert_equal 80, @exam.reload.answer_key_progress
    @q1.update!(annulled_es: true)
    assert_equal 100, @exam.reload.answer_key_progress
  end

  test "só uma matéria pode ser de língua estrangeira" do
    exam = Exam.new(title: "X", exam_subjects_attributes: [
      { subject_id: Subject.first.id, questions_count: 5, points_per_question: 1, foreign_language: true },
      { subject_id: Subject.last.id, questions_count: 5, points_per_question: 1, foreign_language: true }
    ])
    assert_not exam.valid?
    assert_includes exam.errors[:base], "Só uma matéria pode ser de língua estrangeira (Inglês/Espanhol)"
  end
end
