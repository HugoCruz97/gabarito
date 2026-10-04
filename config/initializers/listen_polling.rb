# No Docker Desktop com Windows, o container não recebe os avisos de "arquivo alterado"
# (inotify) da pasta montada. Com LISTEN_FORCE_POLLING=1 a gem listen passa a verificar
# os arquivos periodicamente, o que faz o hot reload do Hotwire Spark funcionar.
if Rails.env.development? && ENV["LISTEN_FORCE_POLLING"] == "1"
  require "listen"

  module ListenForcePolling
    def to(*args, &block)
      options = args.last.is_a?(Hash) ? args.pop : {}
      super(*args, { force_polling: true, latency: 0.5 }.merge(options), &block)
    end
  end

  Listen.singleton_class.prepend(ListenForcePolling)
end
