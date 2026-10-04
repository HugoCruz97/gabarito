# Envia a foto do cartão para o leitor e grava as respostas (em segundo plano)
class ReadAnswerSheetJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError # cartão excluído antes da leitura

  def perform(answer_sheet)
    answer_sheet.read_with_omr!
  end
end
