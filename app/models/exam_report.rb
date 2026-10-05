# Relatório "Notas da turma" de um simulado: ranking, notas por matéria e resumo.
# Só entram cartões já corrigidos (lidos ou conferidos); os demais aparecem como pendências.
class ExamReport
  Row = Struct.new(:position, :sheet, :student, :classroom, :language, :adapted, :scores, :total, :percent, keyword_init: true)

  attr_reader :exam, :classroom

  def initialize(exam, classroom: nil)
    @exam = exam
    @classroom = classroom
  end

  def subjects
    @subjects ||= exam.exam_subjects.includes(:subject).to_a
  end

  # Turmas que aparecem no filtro: as do simulado ou, sem turma vinculada, as dos alunos com cartão
  def classrooms
    @classrooms ||= if exam.classrooms.any?
      exam.classrooms.order(:name).to_a
    else
      Classroom.where(id: exam.answer_sheets.joins(:student).select("students.classroom_id")).order(:name).to_a
    end
  end

  def rows
    @rows ||= begin
      questions = exam.questions.includes(:exam_subject).to_a
      built = graded_sheets.map do |sheet|
        by_subject = sheet.score_by_subject(questions)
        total = sheet.score.to_d
        Row.new(sheet: sheet, student: sheet.student, classroom: sheet.student&.classroom, language: sheet.language,
                adapted: sheet.adapted?, scores: subjects.map { |es| by_subject[es].to_d },
                total: total, percent: exam.total_points.positive? ? (total * 100 / exam.total_points) : 0)
      end
      rank(built.sort_by { |r| [ -r.total, r.student&.name.to_s ] })
    end
  end

  def average = rows.any? ? rows.sum(&:total) / rows.size : nil
  def highest = rows.map(&:total).max
  def lowest = rows.map(&:total).min

  def subject_averages
    return [] if rows.empty?

    subjects.each_index.map { |i| rows.sum { |r| r.scores[i] } / rows.size }
  end

  # Cartões enviados que ainda não entram no ranking
  def pending_sheets
    scoped(exam.answer_sheets.includes(:student)).reject(&:graded?)
  end

  def needs_review
    rows.map(&:sheet).select { |s| s.read? && s.needs_review? }
  end

  # Alunos das turmas consideradas que não têm cartão neste simulado
  def absent_students
    with_sheet = exam.answer_sheets.where.not(student_id: nil).select(:student_id)
    Student.where(classroom: classroom ? [ classroom ] : classrooms).where.not(id: with_sheet).order(:name).to_a
  end

  def to_xlsx
    Axlsx::Package.new do |package|
      styles = package.workbook.styles
      title = styles.add_style(b: true, sz: 14)
      header = styles.add_style(b: true, bg_color: "EBDFC6", border: { style: :thin, color: "CCB07F" }, alignment: { horizontal: :center, wrap_text: true })
      number = styles.add_style(format_code: "0.00")
      bold_number = styles.add_style(b: true, format_code: "0.00")
      percent = styles.add_style(format_code: "0.0\"%\"")

      package.workbook.add_worksheet(name: "Notas") do |sheet|
        sheet.add_row [ "#{exam.title}#{" — #{classroom.name}" if classroom}" ], style: title
        sheet.add_row [ [ (I18n.l(exam.applied_on) if exam.applied_on), "#{rows.size} alunos corrigidos" ].compact.join(" · ") ]
        sheet.add_row []
        labels = subjects.map { |es| es.foreign_language? ? "Inglês / Espanhol" : es.subject.name }
        sheet.add_row [ "Posição", "Aluno", "Matrícula", "Turma", "Língua", "Prova adaptada", *labels, "Total", "%" ], style: header
        rows.each do |r|
          sheet.add_row [ r.position, r.student&.name || "(sem aluno)", r.student&.registration_number, r.classroom&.name,
                          Exam::LANGUAGES[r.language], r.adapted ? "Sim" : "Não", *r.scores.map(&:to_f), r.total.to_f, r.percent.to_f.round(1) ],
            style: [ nil, nil, nil, nil, nil, nil, *Array.new(subjects.size, number), bold_number, percent ],
            types: [ :integer, :string, :string, :string, :string, :string, *Array.new(subjects.size + 2, :float) ] # matrícula como texto (zeros à esquerda)
        end
        if rows.any?
          sheet.add_row [ nil, "Média", nil, nil, nil, nil, *subject_averages.map(&:to_f), average.to_f, (average * 100 / exam.total_points).to_f.round(1) ],
            style: [ nil, header, nil, nil, nil, nil, *Array.new(subjects.size, bold_number), bold_number, percent ]
        end
        sheet.column_widths 9, 36, 14, 16, 11, 14, *Array.new(subjects.size, 13), 10, 8
      end
    end.to_stream.read
  end

  private

  def graded_sheets
    scoped(exam.answer_sheets.where(status: %w[read reviewed]).includes(:answers, student: :classroom)).to_a
  end

  def scoped(relation)
    classroom ? relation.joins(:student).where(students: { classroom_id: classroom.id }) : relation
  end

  # Empates dividem a posição: 1º, 2º, 2º, 4º
  def rank(sorted)
    sorted.each_with_index do |row, i|
      row.position = i.positive? && row.total == sorted[i - 1].total ? sorted[i - 1].position : i + 1
    end
  end
end
