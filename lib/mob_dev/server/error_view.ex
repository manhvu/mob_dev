defmodule MobDev.ErrorView do
  use Phoenix.Component

  @spec render(String.t(), map()) :: Phoenix.LiveView.Rendered.t() | String.t()
  def render("404.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html>
      <head><title>404 Not Found</title></head>
      <body style="background:#09090b;color:#a1a1aa;font-family:monospace;padding:2rem">
        <h1>404</h1><p>Not found.</p>
      </body>
    </html>
    """
  end

  def render("500.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html>
      <head><title>500 Error</title></head>
      <body style="background:#09090b;color:#a1a1aa;font-family:monospace;padding:2rem">
        <h1>500</h1><p>Internal server error.</p>
      </body>
    </html>
    """
  end

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
