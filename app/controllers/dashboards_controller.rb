class DashboardsController < ApplicationController
  def show
    @counts = {
      exams: Exam.count,
      classrooms: Classroom.count,
      students: Student.count,
      subjects: Subject.count
    }
    @recent_exams = Exam.includes(:classrooms, :questions, exam_subjects: :subject).order(applied_on: :desc, created_at: :desc).limit(6)
  end
end
