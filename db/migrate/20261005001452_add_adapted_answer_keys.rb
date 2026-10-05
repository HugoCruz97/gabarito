# Prova adaptada: mesma estrutura e mesmo cartão-resposta, mas com outro gabarito.
# O aluno marcado como "adaptado" é corrigido pelo gabarito adaptado do simulado
# (que também tem Inglês/Espanhol e anulação independentes).
class AddAdaptedAnswerKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :adapted, :boolean, null: false, default: false
    add_column :exams, :adapted_answer_key, :boolean, null: false, default: false

    change_table :exam_questions, bulk: true do |t|
      t.string :correct_option_adapted, limit: 1
      t.string :correct_option_es_adapted, limit: 1
      t.boolean :annulled_adapted, null: false, default: false
      t.boolean :annulled_es_adapted, null: false, default: false
    end
  end
end
