# Importação de alunos por planilha: envio → prévia → confirmação.
# Entre a prévia e a confirmação o arquivo fica guardado no Active Storage (só a
# referência assinada vai no formulário) e é lido de novo ao confirmar.
class StudentImportsController < ApplicationController
  def new
    @classrooms = Classroom.order(:name)
  end

  def template
    send_data StudentImport.template, filename: "modelo-alunos.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  # Prévia: lê a planilha e mostra o que vai acontecer com cada linha
  def create
    file = params[:file]
    unless file.respond_to?(:original_filename) && File.extname(file.original_filename).casecmp?(".xlsx")
      return redirect_to new_student_import_path, alert: "Escolha uma planilha do Excel (.xlsx)."
    end

    blob = ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename)
    @signed_id = blob.signed_id(expires_in: 1.hour)
    @default_classroom = Classroom.find_by(id: params[:default_classroom_id])
    @import = build_import(blob)
  rescue StudentImport::InvalidFile => e
    blob&.purge_later
    redirect_to new_student_import_path, alert: e.message
  end

  def confirm
    blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
    @default_classroom = Classroom.find_by(id: params[:default_classroom_id])
    result = build_import(blob).commit!
    blob.purge_later
    redirect_to students_path, notice: "Importação concluída: #{summary(result)}."
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_student_import_path, alert: "A prévia expirou. Envie a planilha de novo."
  rescue StudentImport::InvalidFile, ActiveRecord::RecordInvalid => e
    redirect_to new_student_import_path, alert: "Nada foi importado: #{e.message}"
  end

  private

  def build_import(blob)
    blob.open { |file| StudentImport.new(file.path, default_classroom: @default_classroom) }
  end

  def summary(counts)
    parts = []
    parts << "#{counts[:create]} #{counts[:create] == 1 ? 'aluno novo' : 'alunos novos'}" if counts[:create]
    parts << "#{counts[:update]} #{counts[:update] == 1 ? 'atualizado' : 'atualizados'}" if counts[:update]
    parts << "#{counts[:unchanged]} sem mudança" if counts[:unchanged]
    parts << "#{counts[:error]} com erro (ignorados)" if counts[:error]
    parts.to_sentence
  end
end
