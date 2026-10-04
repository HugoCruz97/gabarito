# Leitor de cartões-resposta (serviço Python em omr/, container "omr" no compose.yml)
Rails.application.configure do
  config.x.omr.url = ENV.fetch("OMR_URL", "http://localhost:8000")

  # Modelos de cartão que o leitor conhece (PDFs em omr/templates/<chave>.pdf)
  config.x.omr.templates = {
    "meta_simulado_enem_40q" => { name: "Meta Simulado — modelo ENEM (40 questões, A–E)", questions: 40, options: 5 }
  }
  config.x.omr.default_template = "meta_simulado_enem_40q"
end
