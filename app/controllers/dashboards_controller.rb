class DashboardsController < ApplicationController
  def show
    @counts = {
      exams: Exam.count,
      classrooms: Classroom.count,
      students: Student.count,
      subjects: Subject.count
    }
    @recent_exams = Exam.includes(:classrooms, :questions, exam_subjects: :subject).order(applied_on: :desc, created_at: :desc).limit(4)
    @pending_keys = Exam.where(id: ExamQuestion.where(correct_option: nil, annulled: false).select(:exam_id)).count

    @onboarding = [
      [ "Cadastre as matérias", @counts[:subjects].positive?, subjects_path ],
      [ "Crie as turmas", @counts[:classrooms].positive?, new_classroom_path ],
      [ "Cadastre os alunos", @counts[:students].positive?, new_student_path ],
      [ "Monte o primeiro simulado", @counts[:exams].positive?, new_exam_path ],
      [ "Preencha o gabarito", @counts[:exams].positive? && @pending_keys.zero?, exams_path ]
    ]
  end
end
