require "test_helper"

class AnswerSheetReadingTest < ActiveSupport::TestCase
  # Leitor falso: devolve um resultado fixo ou levanta um erro
  class FakeClient
    def initialize(result: nil, error: nil) = (@result, @error = result, error)

    def read(_io, filename:, template:)
      raise @error if @error

      @result
    end
  end

  setup do
    port = Subject.create!(name: "Português")
    lingua = Subject.create!(name: "Língua Estrangeira")
    @exam = Exam.create!(title: "Meta", exam_subjects_attributes: [
      { subject_id: lingua.id, questions_count: 2, position: 0, foreign_language: true },
      { subject_id: port.id, questions_count: 2, position: 1 }
    ])
    q1, q2, q3, q4 = @exam.questions.to_a
    q1.update!(correct_option: "A", correct_option_es: "B")
    q2.update!(correct_option: "C", correct_option_es: "D")
    q3.update!(correct_option: "E")
    q4.update!(correct_option: "A")

    @student = Classroom.create!(name: "3ª série").students.create!(name: "Ana")
    @sheet = @exam.answer_sheets.create!(student: @student, image: sheet_image)
  end

  def reading(language: "espanhol", questions: nil)
    {
      "language" => language,
      "questions" => questions || [
        { "number" => 1, "answer" => "B", "status" => "ok", "confidence" => 0.9 },
        { "number" => 2, "answer" => "D", "status" => "ok", "confidence" => 0.9 },
        { "number" => 3, "answer" => "E", "status" => "ok", "confidence" => 0.9 },
        { "number" => 4, "answer" => "A", "status" => "ok", "confidence" => 0.9 }
      ],
      "overlay_jpeg_base64" => Base64.encode64(file_fixture("cartao.jpg").binread)
    }
  end

  test "grava as marcações, a língua e calcula a nota" do
    @sheet.read_with_omr!(FakeClient.new(result: reading))

    assert @sheet.reload.read?
    assert_equal "espanhol", @sheet.language
    assert_equal 20, @sheet.score # tudo certo pelo gabarito de Espanhol
    assert_equal %w[B D E A], @sheet.answers.joins(:exam_question).order("exam_questions.number").pluck(:marked_option)
    assert @sheet.overlay.attached?
    assert_not @sheet.needs_review?
  end

  test "marcação múltipla vale zero e pede revisão; duvidosa também pede" do
    questions = reading["questions"].dup
    questions[0] = { "number" => 1, "answer" => nil, "status" => "multiple", "confidence" => 0.8 }
    questions[2] = { "number" => 3, "answer" => "E", "status" => "doubtful", "confidence" => 0.4 }
    @sheet.read_with_omr!(FakeClient.new(result: reading(questions: questions)))

    assert_equal 15, @sheet.reload.score # Q1 zera (−5); duvidosa conta a letra sugerida
    assert @sheet.needs_review?
    assert_equal [ "1 marcação duvidosa", "1 com mais de uma alternativa" ], @sheet.review_reasons
  end

  test "sem língua marcada pede revisão" do
    @sheet.read_with_omr!(FakeClient.new(result: reading(language: nil)))
    assert_includes @sheet.reload.review_reasons, "língua (Inglês/Espanhol) não marcada"
  end

  test "foto ilegível marca o cartão como não lido, com o motivo" do
    @sheet.read_with_omr!(FakeClient.new(error: OmrClient::UnreadableImage.new("Não encontrei o cartão na imagem.")))

    assert @sheet.reload.failed?
    assert_equal "Não encontrei o cartão na imagem.", @sheet.error_message
  end

  test "mudar o gabarito recalcula as notas já lançadas" do
    @sheet.read_with_omr!(FakeClient.new(result: reading))
    @exam.questions.find_by(number: 3).update!(correct_option: "A")
    @exam.regrade_answer_sheets!

    assert_equal 15, @sheet.reload.score
  end

  test "não aceita arquivo que não é imagem nem dois cartões do mesmo aluno" do
    txt = @exam.answer_sheets.new(image: fixture_file_upload("nao_e_imagem.txt", "text/plain"))
    assert_not txt.valid?
    assert_includes txt.errors[:image], "precisa ser uma foto JPG, PNG ou WEBP"

    dup = @exam.answer_sheets.new(student: @student, image: sheet_image)
    assert_not dup.valid?
    assert_includes dup.errors[:student_id], "já tem um cartão neste simulado"
  end

  test "simulado com mais questões que o cartão não aceita envio" do
    big = Exam.create!(title: "Grande", exam_subjects_attributes: [ { subject_id: Subject.first.id, questions_count: 41 } ])
    sheet = big.answer_sheets.new(image: sheet_image)
    assert_not sheet.valid?
    assert_includes sheet.errors[:base], "O simulado tem 41 questões, mas o cartão-resposta só tem 40"
  end
end
