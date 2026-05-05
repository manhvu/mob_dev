import Config

config :dala_dev, DalaDev.Server.Endpoint,
  render_errors: [view: DalaDev.ErrorView, accepts: ~w(html), layout: false]
