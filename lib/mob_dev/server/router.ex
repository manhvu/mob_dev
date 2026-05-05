defmodule DalaDev.Server.Router do
  use Phoenix.Router, helpers: false
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:put_root_layout, html: {DalaDev.Server.Layouts, :root})
  end

  scope "/" do
    pipe_through(:browser)
    live("/", DalaDev.Server.DashboardLive)
    live("/web", DalaDev.Server.WebLive)
    live("/web/:feature", DalaDev.Server.WebLive)
    live("/cluster", DalaDev.Server.ClusterVizLive)
    live("/observer", DalaDev.Server.ObserverLive)
    live("/observer/:node", DalaDev.Server.ObserverLive)
    live("/observer/:node/system", DalaDev.Server.ObserverLive.System)
    live("/observer/:node/processes", DalaDev.Server.ObserverLive.Processes)
    live("/observer/:node/ets", DalaDev.Server.ObserverLive.ETS)
    live("/observer/:node/applications", DalaDev.Server.ObserverLive.Applications)
    live("/observer/:node/modules", DalaDev.Server.ObserverLive.Modules)
    live("/observer/:node/ports", DalaDev.Server.ObserverLive.Ports)
    live("/observer/:node/load", DalaDev.Server.ObserverLive.Load)
    live("/observer/:node/tracing", DalaDev.Server.ObserverLive.Tracing)

    # Feature-specific routes for direct access
    live("/dashboard", DalaDev.Server.DashboardLive)
    live("/devices", DalaDev.Server.WebLive)
    live("/deploy", DalaDev.Server.WebLive)
    live("/emulators", DalaDev.Server.WebLive)
    live("/provision", DalaDev.Server.WebLive)
    live("/release", DalaDev.Server.WebLive)
    live("/profiling", DalaDev.Server.WebLive)
    live("/ci", DalaDev.Server.WebLive)
    live("/logs", DalaDev.Server.WebLive)
    live("/settings", DalaDev.Server.WebLive)
  end
end
