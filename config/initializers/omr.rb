# Leitor de cartões-resposta (serviço Python em omr/, container "omr" no compose.yml)
Rails.application.configure do
  config.x.omr.url = ENV.fetch("OMR_URL", "http://localhost:8000")

  # O leitor descobre a grade de bolinhas na própria foto (serve para qualquer variação
  # do cartão). Os modelos em PDF (omr/templates/<chave>.pdf) são só reserva, usados
  # quando a leitura automática falha e o simulado tem exatamente o formato do modelo.
  config.x.omr.templates = {
    "meta_simulado_enem_40q" => { name: "Meta Simulado — modelo ENEM (40 questões, A–E)", questions: 40, options: 5 }
  }
  config.x.omr.default_template = "meta_simulado_enem_40q"
end
