defmodule MobDev.Server.Router do
  use Phoenix.Router, helpers: false
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:put_root_layout, html: {MobDev.Server.Layouts, :root})
  end

  scope "/" do
    pipe_through(:browser)
    live("/", MobDev.Server.DashboardLive)
    live("/web", MobDev.Server.WebLive)
    live("/web/:feature", MobDev.Server.WebLive)
    live("/cluster", MobDev.Server.ClusterVizLive)
    live("/observer", MobDev.Server.ObserverLive)
    live("/observer/:node", MobDev.Server.ObserverLive)
    live("/observer/:node/system", MobDev.Server.ObserverLive.System)
    live("/observer/:node/processes", MobDev.Server.ObserverLive.Processes)
    live("/observer/:node/ets", MobDev.Server.ObserverLive.ETS)
    live("/observer/:node/applications", MobDev.Server.ObserverLive.Applications)
    live("/observer/:node/modules", MobDev.Server.ObserverLive.Modules)
    live("/observer/:node/ports", MobDev.Server.ObserverLive.Ports)
    live("/observer/:node/load", MobDev.Server.ObserverLive.Load)
    live("/observer/:node/tracing", MobDev.Server.ObserverLive.Tracing)

    # Feature-specific routes for direct access
    live("/dashboard", MobDev.Server.DashboardLive)
    live("/devices", MobDev.Server.WebLive)
    live("/deploy", MobDev.Server.WebLive)
    live("/emulators", MobDev.Server.WebLive)
    live("/provision", MobDev.Server.WebLive)
    live("/release", MobDev.Server.WebLive)
    live("/profiling", MobDev.Server.WebLive)
    live("/ci", MobDev.Server.WebLive)
    live("/logs", MobDev.Server.WebLive)
    live("/settings", MobDev.Server.WebLive)
  end
end
