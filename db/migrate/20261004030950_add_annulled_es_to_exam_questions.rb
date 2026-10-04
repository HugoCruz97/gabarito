# Em língua estrangeira, Inglês e Espanhol são questões diferentes: anular uma não anula a outra.
# `annulled` passa a valer para o Inglês (e para as demais matérias) e `annulled_es` para o Espanhol.
class AddAnnulledEsToExamQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :exam_questions, :annulled_es, :boolean, null: false, default: false
  end
end
