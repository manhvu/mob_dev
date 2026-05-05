defmodule MobDev.Server.WebLive do
  @moduledoc """
  Main web UI layout for mob.web - provides navigation and integration
  for all mob_dev features in a single interface.
  """
  use Phoenix.LiveView

  @features [
    %{id: :dashboard, name: "Dashboard", icon: "dashboard", path: "/dashboard"},
    %{id: :devices, name: "Devices", icon: "devices", path: "/devices"},
    %{id: :deploy, name: "Deploy", icon: "deploy", path: "/deploy"},
    %{id: :emulators, name: "Emulators", icon: "emulators", path: "/emulators"},
    %{id: :observer, name: "Observer", icon: "observer", path: "/observer"},
    %{id: :provision, name: "Provision", icon: "provision", path: "/provision"},
    %{id: :release, name: "Release", icon: "release", path: "/release"},
    %{id: :profiling, name: "Profiling", icon: "profiling", path: "/profiling"},
    %{id: :ci, name: "CI Testing", icon: "ci", path: "/ci"},
    %{id: :logs, name: "Logs", icon: "logs", path: "/logs"},
    %{id: :settings, name: "Settings", icon: "settings", path: "/settings"}
  ]

  def render(assigns) do
    ~H"""
    <div class="mob-web-container">
      <!-- Sidebar Navigation -->
      <aside class="mob-sidebar">
        <div class="mob-sidebar-header">
          <h1 class="mob-logo">Mob</h1>
          <span class="mob-version">v0.3.28</span>
        </div>

        <nav class="mob-nav">
          <%= for feature <- @features do %>
            <a href={feature.path} class={"mob-nav-item #{if @active_feature == feature.id, do: "active"}"}>
              <span class="mob-nav-icon">
                <%= render_icon(feature.icon) %>
              </span>
              <span class="mob-nav-text"><%= feature.name %></span>
            </a>
          <% end %>
        </nav>

        <div class="mob-sidebar-footer">
          <div class="mob-connection-status">
            <span class={"status-dot #{if @node_connected, do: "connected", else: "disconnected"}"}></span>
            <span><%= if @node_connected, do: "Node Connected", else: "Local Mode" %></span>
          </div>
        </div>
      </aside>

      <!-- Main Content Area -->
      <main class="mob-main-content">
        <div class="mob-content-header">
          <h2><%= @page_title %></h2>
          <div class="mob-actions">
            <%= render_quick_actions(assigns) %>
          </div>
        </div>

        <div class="mob-content-body">
          <%= render_content(@active_feature, assigns) %>
        </div>
      </main>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:features, @features)
      |> assign(:active_feature, :dashboard)
      |> assign(:page_title, "Dashboard")
      |> assign(:node_connected, Node.alive?())
      |> assign(:device_count, 0)
      |> assign(:emulator_count, 0)

    {:ok, socket}
  end

  def handle_params(%{"feature" => feature_id}, _uri, socket) do
    feature_id = String.to_atom(feature_id)
    feature = Enum.find(@features, &(&1.id == feature_id))

    socket =
      if feature do
        socket
        |> assign(:active_feature, feature.id)
        |> assign(:page_title, feature.name)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_params(_params, %URI{path: path}, socket) do
    # Extract feature from path
    feature_id =
      case path do
        "/devices" -> :devices
        "/deploy" -> :deploy
        "/emulators" -> :emulators
        "/provision" -> :provision
        "/release" -> :release
        "/profiling" -> :profiling
        "/ci" -> :ci
        "/logs" -> :logs
        "/settings" -> :settings
        _ -> :dashboard
      end

    feature = Enum.find(@features, &(&1.id == feature_id))

    socket =
      if feature do
        socket
        |> assign(:active_feature, feature.id)
        |> assign(:page_title, feature.name)
      else
        socket
      end

    {:noreply, socket}
  end

  defp render_icon(:dashboard),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"3\" y=\"3\" width=\"7\" height=\"7\"></rect><rect x=\"14\" y=\"3\" width=\"7\" height=\"7\"></rect><rect x=\"14\" y=\"14\" width=\"7\" height=\"7\"></rect><rect x=\"3\" y=\"14\" width=\"7\" height=\"7\"></rect></svg>"

  defp render_icon(:devices),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"5\" y=\"2\" width=\"14\" height=\"20\" rx=\"2\" ry=\"2\"></rect><line x1=\"12\" y1=\"18\" x2=\"12.01\" y2=\"18\"></line></svg>"

  defp render_icon(:deploy),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4\"></path><polyline points=\"7 10 12 15 17 10\"></polyline><line x1=\"12\" y1=\"15\" x2=\"12\" y2=\"3\"></line></svg>"

  defp render_icon(:emulators),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"2\" y=\"3\" width=\"20\" height=\"14\" rx=\"2\" ry=\"2\"></rect><line x1=\"8\" y1=\"21\" x2=\"16\" y2=\"21\"></line><line x1=\"12\" y1=\"17\" x2=\"12\" y2=\"21\"></line></svg>"

  defp render_icon(:observer),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z\"></path><circle cx=\"12\" cy=\"12\" r=\"3\"></circle></svg>"

  defp render_icon(:provision),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"3\" y=\"11\" width=\"18\" height=\"11\" rx=\"2\" ry=\"2\"></rect><path d=\"M7 11V7a5 5 0 0 1 10 0v4\"></path></svg>"

  defp render_icon(:release),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"10\"></circle><polyline points=\"12 6 12 12 16 14\"></polyline></svg>"

  defp render_icon(:profiling),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><line x1=\"18\" y1=\"20\" x2=\"18\" y2=\"10\"></line><line x1=\"12\" y1=\"20\" x2=\"12\" y2=\"4\"></line><line x1=\"6\" y1=\"20\" x2=\"6\" y2=\"14\"></line></svg>"

  defp render_icon(:ci),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M22 12h-4l-3 9L9 3l-3 9H2\"></path></svg>"

  defp render_icon(:logs),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z\"></path><polyline points=\"14 2 14 8 20 8\"></polyline><line x1=\"16\" y1=\"13\" x2=\"8\" y2=\"13\"></line><line x1=\"16\" y1=\"17\" x2=\"8\" y2=\"17\"></line><polyline points=\"10 9 9 9 8 9\"></polyline></svg>"

  defp render_icon(:settings),
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"3\"></circle><path d=\"M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z\"></path></svg>"

  defp render_quick_actions(assigns) do
    ~H"""
    <button class="mob-btn mob-btn-primary">Quick Action 1</button>
    <button class="mob-btn mob-btn-secondary">Quick Action 2</button>
    """
  end

  defp render_content(:dashboard, assigns) do
    ~H"""
    <div class="mob-dashboard">
      <div class="mob-stats-grid">
        <div class="mob-stat-card">
          <h3>Devices</h3>
          <p class="mob-stat-number"><%= @device_count %></p>
        </div>
        <div class="mob-stat-card">
          <h3>Emulators</h3>
          <p class="mob-stat-number"><%= @emulator_count %></p>
        </div>
        <div class="mob-stat-card">
          <h3>Status</h3>
          <p class="mob-stat-text">Online</p>
        </div>
      </div>

      <div class="mob-recent-activity">
        <h3>Recent Activity</h3>
        <p>Activity feed coming soon...</p>
      </div>
    </div>
    """
  end

  defp render_content(:devices, assigns) do
    ~H"""
    <div class="mob-devices-view">
      <h3>Device Management</h3>
      <p>Android and iOS device management interface.</p>
      <!-- Will integrate MobDev.Discovery modules -->
    </div>
    """
  end

  defp render_content(:deploy, assigns) do
    ~H"""
    <div class="mob-deploy-view">
      <h3>Deploy Applications</h3>
      <p>Deploy to connected devices and emulators.</p>
      <!-- Will integrate MobDev.Deployer -->
    </div>
    """
  end

  defp render_content(:emulators, assigns) do
    ~H"""
    <div class="mob-emulators-view">
      <h3>Emulator Management</h3>
      <p>Manage Android AVDs and iOS simulators.</p>
      <!-- Will integrate MobDev.Emulators -->
    </div>
    """
  end

  defp render_content(:observer, assigns) do
    ~H"""
    <div class="mob-observer-view">
      <h3>Observer</h3>
      <p>Remote node monitoring. <a href="/observer">Open Full Observer</a></p>
    </div>
    """
  end

  defp render_content(:provision, assigns) do
    ~H"""
    <div class="mob-provision-view">
      <h3>Provisioning</h3>
      <p>Code signing and provisioning profile management.</p>
      <!-- Will integrate MobDev.Provision -->
    </div>
    """
  end

  defp render_content(:release, assigns) do
    ~H"""
    <div class="mob-release-view">
      <h3>Release Management</h3>
      <p>Build and manage releases for Android and iOS.</p>
      <!-- Will integrate MobDev.NativeBuild, release tasks -->
    </div>
    """
  end

  defp render_content(:profiling, assigns) do
    ~H"""
    <div class="mob-profiling-view">
      <h3>Profiling</h3>
      <p>Performance profiling and analysis tools.</p>
      <!-- Will integrate MobDev.Profiling -->
    </div>
    """
  end

  defp render_content(:ci, assigns) do
    ~H"""
    <div class="mob-ci-view">
      <h3>CI Testing</h3>
      <p>Continuous integration test management.</p>
      <!-- Will integrate MobDev.CITesting -->
    </div>
    """
  end

  defp render_content(:logs, assigns) do
    ~H"""
    <div class="mob-logs-view">
      <h3>Logs</h3>
      <p>Centralized log viewing and filtering.</p>
      <!-- Will integrate MobDev.Server.LogBuffer -->
    </div>
    """
  end

  defp render_content(:settings, assigns) do
    ~H"""
    <div class="mob-settings-view">
      <h3>Settings</h3>
      <p>Configuration and preferences.</p>
    </div>
    """
  end

  defp render_content(_, assigns) do
    ~H"""
    <div class="mob-not-found">
      <h3>Feature not found</h3>
    </div>
    """
  end
end
