class ReportsController < ApplicationController
  def show
    @exam = Exam.find(params[:exam_id])
    @report = ExamReport.new(@exam, classroom: Classroom.find_by(id: params[:turma]))

    respond_to do |format|
      format.html
      format.xlsx do
        name = [ @exam.title, @report.classroom&.name ].compact.join(" - ").parameterize
        send_data @report.to_xlsx, filename: "notas-#{name}.xlsx",
          type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      end
    end
  end
end
