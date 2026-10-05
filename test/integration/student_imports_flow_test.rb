require "test_helper"

class StudentImportsFlowTest < ActionDispatch::IntegrationTest
  def xlsx_upload(rows)
    file = Tempfile.new([ "alunos", ".xlsx" ])
    Axlsx::Package.new { |p| p.workbook.add_worksheet { |s| rows.each { |r| s.add_row(r) } } }.serialize(file.path)
    Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", original_filename: "alunos.xlsx")
  end

  test "envia, vê a prévia sem gravar nada e confirma" do
    get new_student_import_path
    assert_response :success

    post student_import_path, params: { file: xlsx_upload([ %w[Nome Matrícula Turma], [ "Gina Alves", "900", "1ª série" ] ]) }
    assert_response :success
    assert_select "td", text: "Gina Alves"
    assert_equal 0, Student.count # prévia não grava

    signed_id = css_select("input[name='signed_id']").first["value"]
    post confirm_student_import_path, params: { signed_id: signed_id }
    assert_redirected_to students_path
    assert_equal "1ª série", Student.find_by!(name: "Gina Alves").classroom.name
  end

  test "baixa a planilha modelo" do
    get template_student_import_path
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
  end

  test "arquivo que não é .xlsx é recusado" do
    post student_import_path, params: { file: fixture_file_upload("nao_e_imagem.txt", "text/plain") }
    assert_redirected_to new_student_import_path
    assert_match ".xlsx", flash[:alert]
  end
end
