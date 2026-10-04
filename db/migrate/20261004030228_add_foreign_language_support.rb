# Língua estrangeira no modelo ENEM: a prova traz Inglês e Espanhol nas mesmas questões,
# o aluno escolhe uma e marca a língua no cartão. Por isso essas questões têm dois gabaritos.
class AddForeignLanguageSupport < ActiveRecord::Migration[8.1]
  def change
    add_column :exam_subjects, :foreign_language, :boolean, null: false, default: false
    add_column :exam_questions, :correct_option_es, :string, limit: 1
    add_column :answer_sheets, :language, :string
  end
end
