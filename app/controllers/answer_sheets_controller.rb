class AnswerSheetsController < ApplicationController
  before_action :set_exam
  before_action :set_answer_sheet, only: %i[show update destroy reprocess]

  def new
    load_students
  end

  # Recebe várias fotos de uma vez, cada uma com o aluno escolhido na hora do envio:
  # sheets[<i>][image], sheets[<i>][student_id]
  def create
    entries = params.fetch(:sheets, {}).values.select { |entry| entry[:image].present? }
    if entries.empty?
      load_students
      flash.now[:alert] = "Escolha pelo menos uma foto de cartão."
      return render :new, status: :unprocessable_entity
    end

    created, failures = [], []
    entries.each do |entry|
      sheet = @exam.answer_sheets.new(image: entry[:image], student_id: entry[:student_id].presence)
      if sheet.save
        created << sheet
      else
        failures << "#{entry[:image].original_filename}: #{sheet.errors.full_messages.to_sentence}"
      end
    end

    created.each { |sheet| ReadAnswerSheetJob.perform_later(sheet) }

    if failures.any?
      flash[:alert] = "Não enviados — #{failures.join(' · ')}"
    end
    redirect_to exam_path(@exam, anchor: "cartoes"),
      notice: (created.any? ? "#{created.size} #{created.size == 1 ? 'cartão enviado' : 'cartões enviados'} para leitura." : nil)
  end

  def show
    @answers = @answer_sheet.answers.index_by(&:exam_question_id)
    @questions_by_subject = @exam.questions.includes(exam_subject: :subject).group_by(&:exam_subject)
    @scores = @answer_sheet.score_by_subject
    load_students
  end

  # Revisão da professora: aluno, língua e cada marcação podem ser corrigidos.
  def update
    AnswerSheet.transaction do
      @answer_sheet.update!(review_params)

      answers = @answer_sheet.answers.index_by(&:exam_question_id)
      params.fetch(:answers, {}).each do |question_id, value|
        answer = answers[question_id.to_i] || @answer_sheet.answers.build(exam_question_id: question_id)
        option = value.presence_in(Exam::OPTIONS)
        multiple = value == "multiple"
        next if answer.persisted? && answer.marked_option == option && answer.multiple_marks? == multiple

        answer.update!(marked_option: option, multiple_marks: multiple, status: "manual")
      end

      @answer_sheet.update!(status: :reviewed)
      @answer_sheet.grade!
    end
    notice = "Correção de #{@answer_sheet.student&.name || 'cartão'} confirmada."
    if (next_sheet = @exam.next_sheet_to_review(after: @answer_sheet))
      redirect_to exam_answer_sheet_path(@exam, next_sheet), notice: "#{notice} Próximo para revisar:"
    else
      redirect_to exam_path(@exam, anchor: "cartoes"), notice: notice
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to exam_answer_sheet_path(@exam, @answer_sheet), alert: e.record.errors.full_messages.to_sentence
  end

  def reprocess
    @answer_sheet.update!(status: :pending, error_message: nil)
    ReadAnswerSheetJob.perform_later(@answer_sheet)
    redirect_to exam_path(@exam, anchor: "cartoes"), notice: "Cartão enviado para leitura novamente."
  end

  def destroy
    @answer_sheet.destroy!
    redirect_to exam_path(@exam, anchor: "cartoes"), notice: "Cartão excluído.", status: :see_other
  end

  private

  def set_exam
    @exam = Exam.find(params[:exam_id])
  end

  def set_answer_sheet
    @answer_sheet = @exam.answer_sheets.find(params[:id])
  end

  # Alunos das turmas do simulado (ou todos, se o simulado não tiver turma)
  def load_students
    scope = @exam.classrooms.any? ? Student.where(classroom: @exam.classrooms) : Student.all
    @students = scope.includes(:classroom).order(:name)
    @students_with_sheet = @exam.answer_sheets.where.not(student_id: nil).pluck(:student_id).to_set
  end

  def review_params
    params.fetch(:answer_sheet, {}).permit(:student_id, :language).tap do |p|
      p[:language] = p[:language].presence if p.key?(:language)
      p[:student_id] = p[:student_id].presence if p.key?(:student_id)
    end
  end
end
