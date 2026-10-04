require "net/http"

# Cliente HTTP do serviço leitor de cartões (omr/omr/server.py)
class OmrClient
  class Error < StandardError; end
  # A foto chegou, mas não deu para ler (cartão não encontrado, imagem inválida...)
  class UnreadableImage < Error; end

  TIMEOUT = 60

  def initialize(url: Rails.configuration.x.omr.url)
    @uri = URI.join(url, "/read")
  end

  # Retorna o hash do leitor: "questions", "language", "needs_review", "alignment", "overlay_jpeg_base64"
  def read(io, filename:, template:)
    request = Net::HTTP::Post.new(@uri)
    request.set_form([ [ "image", io, { filename: filename } ], [ "template", template ] ], "multipart/form-data")

    response = Net::HTTP.start(@uri.host, @uri.port, open_timeout: 5, read_timeout: TIMEOUT) { |http| http.request(request) }
    body = JSON.parse(response.body) rescue {}

    case response
    when Net::HTTPSuccess then body
    when Net::HTTPUnprocessableEntity then raise UnreadableImage, body["error"] || "Não foi possível ler o cartão."
    else raise Error, body["error"] || "Leitor respondeu #{response.code}."
    end
  rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "O leitor de cartões está fora do ar (#{e.class.name.demodulize})."
  end
end
