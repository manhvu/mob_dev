import Config

config :mob_dev, MobDev.Server.Endpoint,
  render_errors: [view: MobDev.ErrorView, accepts: ~w(html), layout: false]
