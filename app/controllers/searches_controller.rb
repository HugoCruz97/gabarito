class SearchesController < ApplicationController
  LIMIT = 6

  def show
    term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"

    @students = Student.includes(:classroom).where("students.name ILIKE :t OR students.registration_number ILIKE :t", t: term).order(:name).limit(LIMIT)
    @classrooms = Classroom.where("name ILIKE ?", term).order(:name).limit(LIMIT)
    @exams = Exam.where("title ILIKE ?", term).order(applied_on: :desc).limit(LIMIT)
    @subjects = Subject.where("name ILIKE ?", term).order(:name).limit(LIMIT)
  end
end
