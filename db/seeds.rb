# Dados de exemplo para desenvolvimento: bin/rails db:seed
return unless Rails.env.development?

subjects = %w[Português Matemática História Geografia Ciências Inglês].map do |name|
  Subject.find_or_create_by!(name: name)
end

classroom = Classroom.find_or_create_by!(name: "9º ano A", school_year: Date.current.year)
[ "Ana Souza", "Bruno Lima", "Carla Mendes", "Daniel Rocha", "Eduarda Alves" ].each_with_index do |name, i|
  classroom.students.find_or_create_by!(name: name) { |s| s.registration_number = format("2026%03d", i + 1) }
end

unless Exam.exists?(title: "Simulado 1º bimestre")
  exam = Exam.create!(
    title: "Simulado 1º bimestre",
    applied_on: Date.current,
    classrooms: [ classroom ],
    exam_subjects_attributes: [
      { subject_id: subjects[0].id, questions_count: 10, position: 0 },
      { subject_id: subjects[1].id, questions_count: 10, position: 1 }
    ]
  )
  exam.questions.each { |q| q.update!(correct_option: Exam::OPTIONS.first(exam.options_count).sample) }
end

puts "Seeds OK: #{Subject.count} matérias, #{Student.count} alunos, #{Exam.count} simulado(s)"
