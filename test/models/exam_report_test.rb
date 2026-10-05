require "test_helper"

class ExamReportTest < ActiveSupport::TestCase
  setup do
    port = Subject.create!(name: "Português")
    mat = Subject.create!(name: "Matemática")
    @a = Classroom.create!(name: "3ª A")
    @b = Classroom.create!(name: "3ª B")
    @exam = Exam.create!(title: "Meta", classrooms: [ @a, @b ], exam_subjects_attributes: [
      { subject_id: port.id, questions_count: 2, position: 0 },
      { subject_id: mat.id, questions_count: 2, position: 1 }
    ])
    @exam.questions.each { |q| q.update!(correct_option: "A") }
  end

  # acertos: quantas das 4 questões (na ordem) o aluno acerta
  def graded(student, hits, status: :read)
    sheet = @exam.answer_sheets.create!(student: student, image: sheet_image, status: status)
    @exam.questions.each_with_index { |q, i| sheet.answers.create!(exam_question: q, marked_option: i < hits ? "A" : "B") }
    sheet.tap(&:grade!)
  end

  test "ranking por nota, com empate dividindo a posição" do
    ana, bia, caio, davi = %w[Ana Bia Caio Davi].map { |n| @a.students.create!(name: n) }
    graded(ana, 2) # 10
    graded(bia, 4) # 20
    graded(caio, 2) # 10
    graded(davi, 1) # 5

    report = ExamReport.new(@exam)
    assert_equal [ [ 1, "Bia" ], [ 2, "Ana" ], [ 2, "Caio" ], [ 4, "Davi" ] ], report.rows.map { |r| [ r.position, r.student.name ] }
    assert_equal [ 20, 10, 10, 5 ], report.rows.map(&:total)
    assert_equal 11.25, report.average
    assert_equal [ 20, 5 ], [ report.highest, report.lowest ]
    assert_equal [ 8.75, 2.5 ], report.subject_averages # Português 10+10+10+5; Matemática só a Bia (10)
  end

  test "filtra por turma e lista quem não tem cartão" do
    ana = @a.students.create!(name: "Ana")
    @a.students.create!(name: "Edu") # sem cartão
    bruno = @b.students.create!(name: "Bruno")
    graded(ana, 4)
    graded(bruno, 4)

    report = ExamReport.new(@exam, classroom: @a)
    assert_equal [ "Ana" ], report.rows.map { |r| r.student.name }
    assert_equal [ "Edu" ], report.absent_students.map(&:name)
  end

  test "cartões ainda não corrigidos ficam fora do ranking, como pendência" do
    ana = @a.students.create!(name: "Ana")
    bia = @a.students.create!(name: "Bia")
    graded(ana, 4)
    @exam.answer_sheets.create!(student: bia, image: sheet_image, status: :failed)

    report = ExamReport.new(@exam)
    assert_equal [ "Ana" ], report.rows.map { |r| r.student.name }
    assert_equal [ "Bia" ], report.pending_sheets.map { |s| s.student.name }
  end

  test "exporta para Excel com uma linha por aluno e a média" do
    graded(@a.students.create!(name: "Ana"), 4)
    file = Tempfile.new([ "notas", ".xlsx" ])
    file.binmode
    file.write(ExamReport.new(@exam).to_xlsx)
    file.flush

    sheet = Roo::Excelx.new(file.path).sheet(0)
    assert_equal [ "Posição", "Aluno", "Matrícula", "Turma", "Língua", "Prova adaptada", "Português", "Matemática", "Total", "%" ], sheet.row(4)
    assert_equal "Ana", sheet.row(5)[1]
    assert_equal 20.0, sheet.row(5)[8]
    assert_equal "Média", sheet.row(6)[1]
  end
end
