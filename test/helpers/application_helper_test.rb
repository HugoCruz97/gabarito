require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  setup do
    espanhol = Subject.create!(name: "Espanhol")
    port = Subject.create!(name: "Português")
    @exam = Exam.create!(title: "Meta", exam_subjects_attributes: [
      { subject_id: port.id, questions_count: 5, position: 0 },
      { subject_id: espanhol.id, questions_count: 5, position: 1, foreign_language: true }
    ])
    @port, @lingua = @exam.exam_subjects.to_a
  end

  test "matéria de língua aparece com a língua escolhida pelo aluno, não com o nome cadastrado" do
    assert_equal "Inglês", subject_label(@lingua, "ingles")
    assert_equal "Espanhol", subject_label(@lingua, "espanhol")
    assert_equal "Língua estrangeira", subject_label(@lingua, nil)
  end

  test "nas telas do simulado a matéria de língua mostra as duas línguas" do
    assert_equal "Inglês / Espanhol", subject_label(@lingua)
  end

  test "matérias comuns mantêm o nome cadastrado" do
    assert_equal "Português", subject_label(@port)
    assert_equal "Português", subject_label(@port, "ingles")
  end
end
