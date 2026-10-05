require "roo"

# Importação de alunos a partir de uma planilha Excel (.xlsx).
#
# Colunas reconhecidas pelo cabeçalho (sem diferenciar maiúsculas/acentos):
#   Nome (obrigatória) · Matrícula · Turma · Adaptada (Sim/Não)
#
# Nada é gravado até `commit!`: primeiro a planilha vira uma prévia (`rows`), em que cada
# linha diz o que vai acontecer — criar, atualizar, manter ou erro.
class StudentImport
  class InvalidFile < StandardError; end

  HEADERS = {
    name: [ "nome", "aluno", "nome do aluno", "nome completo", "estudante" ],
    registration_number: [ "matricula", "ra", "registro", "numero de matricula", "n matricula" ],
    classroom: [ "turma", "classe", "serie", "sala" ],
    adapted: [ "adaptada", "adaptado", "prova adaptada", "prova adaptada?" ]
  }.freeze
  YES = %w[sim s x yes y true 1 adaptada adaptado].freeze

  Row = Struct.new(:line, :name, :registration_number, :classroom_name, :adapted, :action, :error, :student,
                   :changes, keyword_init: true) do
    def error? = action == :error
  end

  attr_reader :rows

  # default_classroom: turma usada nas linhas sem a coluna/valor de turma
  def initialize(path, default_classroom: nil)
    @default_classroom = default_classroom
    @rows = parse(path)
  end

  def self.template
    Axlsx::Package.new do |package|
      package.workbook.add_worksheet(name: "Alunos") do |sheet|
        header = sheet.styles.add_style(b: true, bg_color: "EBDFC6", border: { style: :thin, color: "CCB07F" })
        sheet.add_row [ "Nome", "Matrícula", "Turma", "Adaptada" ], style: header
        sheet.add_row [ "Ana Souza", "20260001", "3ª série A", "Não" ]
        sheet.add_row [ "Bruno Lima", "20260002", "3ª série A", "Sim" ]
        sheet.column_widths 36, 16, 18, 12
      end
    end.to_stream.read
  end

  def counts
    rows.group_by(&:action).transform_values(&:size)
  end

  def new_classrooms
    existing = Classroom.pluck(:name).map { |n| normalize(n) }
    rows.reject(&:error?).filter_map(&:classroom_name).uniq { |n| normalize(n) }.reject { |n| normalize(n).in?(existing) }
  end

  def valid?
    rows.any? { |r| r.action.in?(%i[create update]) }
  end

  # Grava tudo numa transação: turmas novas, alunos novos e atualizações
  def commit!
    ActiveRecord::Base.transaction do
      classrooms = Classroom.all.index_by { |c| normalize(c.name) }
      new_classrooms.each { |name| classrooms[normalize(name)] = Classroom.create!(name: name) }

      rows.each do |row|
        next unless row.action.in?(%i[create update])

        classroom = row.classroom_name ? classrooms.fetch(normalize(row.classroom_name)) : @default_classroom
        attrs = { name: row.name, registration_number: row.registration_number, classroom: classroom, adapted: row.adapted }
        if row.action == :create
          Student.create!(attrs.merge(adapted: row.adapted || false)) # sem a coluna: não adaptado
        else
          row.student.update!(attrs.compact) # sem a coluna: mantém o que já estava
        end
      end
    end
    counts
  end

  private

  def parse(path)
    sheet = Roo::Excelx.new(path).sheet(0)
    header_line, columns = find_header(sheet)
    raise InvalidFile, "Não encontrei a coluna \"Nome\" nas primeiras linhas da planilha." unless columns

    existing_by_registration = Student.where.not(registration_number: nil).index_by(&:registration_number)
    existing_by_name = Student.includes(:classroom).group_by { |s| normalize(s.name) }
    seen = {}

    ((header_line + 1)..sheet.last_row.to_i).filter_map do |line|
      values = columns.transform_values { |col| cell(sheet.cell(line, col)) }
      next if values.values.all?(&:blank?)

      build_row(line, values, existing_by_registration, existing_by_name, seen)
    end
  rescue Zip::Error, ArgumentError, IOError => e
    raise InvalidFile, "Não consegui ler a planilha (#{e.message}). Envie um arquivo .xlsx."
  end

  def find_header(sheet)
    first, last = sheet.first_row.to_i, [ sheet.last_row.to_i, sheet.first_row.to_i + 9 ].min
    (first..last).each do |line|
      row = (1..sheet.last_column.to_i).to_h { |col| [ col, normalize(sheet.cell(line, col)) ] }
      columns = HEADERS.to_h { |field, names| [ field, row.key(row.values.find { |v| v.in?(names) }) ] }.compact
      return [ line, columns ] if columns[:name]
    end
    nil
  end

  def build_row(line, values, by_registration, by_name, seen)
    name = values[:name].to_s.squish
    registration = values[:registration_number].presence
    classroom_name = values[:classroom].to_s.squish.presence
    adapted = values.key?(:adapted) ? normalize(values[:adapted]).in?(YES) : nil
    row = Row.new(line: line, name: name, registration_number: registration, classroom_name: classroom_name, adapted: adapted)

    key = registration || "#{normalize(name)}|#{normalize(classroom_name)}"
    return error(row, "Sem nome") if name.blank?
    return error(row, "Repetido na planilha (linha #{seen[key]})") if seen[key]
    return error(row, "Sem turma (escolha uma turma padrão)") if classroom_name.nil? && @default_classroom.nil?

    seen[key] = line
    existing = registration ? by_registration[registration] : match_by_name(by_name, name, classroom_name)
    return row.tap { |r| r.action = :create } unless existing

    row.student = existing
    row.changes = changes_for(existing, row)
    row.action = row.changes.any? ? :update : :unchanged
    row
  end

  # Sem matrícula, só considera o mesmo aluno se o nome bater dentro da mesma turma
  def match_by_name(by_name, name, classroom_name)
    candidates = by_name[normalize(name)] || []
    target = classroom_name ? normalize(classroom_name) : normalize(@default_classroom&.name)
    candidates.find { |s| normalize(s.classroom.name) == target }
  end

  def changes_for(student, row)
    changes = []
    changes << "nome" if row.name != student.name
    changes << "turma" if row.classroom_name && normalize(row.classroom_name) != normalize(student.classroom.name)
    changes << "prova adaptada" if !row.adapted.nil? && row.adapted != student.adapted?
    changes
  end

  def error(row, message)
    row.action = :error
    row.error = message
    row
  end

  # Números de matrícula vêm do Excel como 20205797.0
  def cell(value)
    value.is_a?(Float) && value == value.floor ? value.to_i.to_s : value.to_s.strip
  end

  def normalize(value)
    I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9 ?]/, " ").squish
  end
end
