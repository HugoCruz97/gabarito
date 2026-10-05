require "test_helper"

class StudentImportTest < ActiveSupport::TestCase
  setup do
    @turma_a = Classroom.create!(name: "3ª série A")
    @existing = @turma_a.students.create!(name: "Ana Souza", registration_number: "100")
  end

  # Monta uma planilha .xlsx temporária com as linhas dadas
  def xlsx(rows)
    file = Tempfile.new([ "alunos", ".xlsx" ])
    Axlsx::Package.new { |p| p.workbook.add_worksheet { |s| rows.each { |r| s.add_row(r) } } }.serialize(file.path)
    file.path
  end

  test "lê as colunas pelo cabeçalho, em qualquer ordem e com variações de nome" do
    path = xlsx([
      [ "Escola Exemplo" ],                                   # linha de título antes do cabeçalho
      [ "Turma", "RA", "Nome do aluno", "Prova adaptada" ],
      [ "3ª série A", 200, "Bruno Lima", "Sim" ],
      [ "3ª série B", 300, "Carla Dias", "não" ]
    ])
    import = StudentImport.new(path)

    assert_equal [ :create, :create ], import.rows.map(&:action)
    bruno = import.rows.first
    assert_equal [ "Bruno Lima", "200", "3ª série A", true ], [ bruno.name, bruno.registration_number, bruno.classroom_name, bruno.adapted ]
    assert_equal [ "3ª série B" ], import.new_classrooms
  end

  test "reconhece alunos já cadastrados pela matrícula e mostra o que muda" do
    path = xlsx([ %w[Nome Matrícula Turma Adaptada], [ "Ana Souza", "100", "3ª série A", "Sim" ], [ "Ana Souza", "100", "3ª série A", "" ] ])
    import = StudentImport.new(path)

    assert_equal :update, import.rows.first.action
    assert_equal [ "prova adaptada" ], import.rows.first.changes
    assert_equal :error, import.rows.last.action
    assert_match "Repetido na planilha", import.rows.last.error
  end

  test "sem matrícula, reconhece pelo nome dentro da mesma turma" do
    @turma_a.students.create!(name: "Davi Rocha")
    path = xlsx([ %w[Nome Turma], [ "davi rocha", "3ª série A" ], [ "Davi Rocha", "3ª série C" ] ])
    import = StudentImport.new(path)

    assert_equal %i[update create], import.rows.map(&:action) # mesmo nome, outra turma = outro aluno
  end

  test "linha sem turma usa a turma padrão; sem padrão vira erro" do
    path = xlsx([ %w[Nome], [ "Eva Prado" ] ])
    assert_equal :error, StudentImport.new(path).rows.first.action
    assert_equal :create, StudentImport.new(path, default_classroom: @turma_a).rows.first.action
  end

  test "confirmar cria turmas e alunos e atualiza os existentes, numa transação só" do
    path = xlsx([ %w[Nome Matrícula Turma Adaptada], [ "Ana Souza", "100", "3ª série A", "Sim" ],
                  [ "Fábio Reis", "400", "3ª série D", "" ], [ "", "500", "3ª série A", "" ] ])
    result = StudentImport.new(path).commit!

    assert_equal({ update: 1, create: 1, error: 1 }, result)
    assert @existing.reload.adapted?
    assert_equal "3ª série D", Student.find_by!(registration_number: "400").classroom.name
  end

  test "planilha sem coluna Nome é recusada" do
    path = xlsx([ %w[Matrícula Turma], [ "1", "A" ] ])
    error = assert_raises(StudentImport::InvalidFile) { StudentImport.new(path) }
    assert_match "Nome", error.message
  end

  test "a planilha modelo pode ser importada" do
    file = Tempfile.new([ "modelo", ".xlsx" ])
    file.binmode
    file.write(StudentImport.template)
    file.flush
    assert_equal %i[create create], StudentImport.new(file.path).rows.map(&:action)
  end
end
