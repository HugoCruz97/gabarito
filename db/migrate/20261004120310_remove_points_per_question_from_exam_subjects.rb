# Cada matéria do simulado vale 10 pontos; o valor de cada questão passa a ser
# calculado (10 ÷ quantidade de questões) em vez de digitado.
class RemovePointsPerQuestionFromExamSubjects < ActiveRecord::Migration[8.1]
  def change
    remove_column :exam_subjects, :points_per_question, :decimal, precision: 6, scale: 2, null: false, default: 0
  end
end
