defmodule DalaDev.Server.Layouts do
  use Phoenix.Component

  @spec root(map()) :: Phoenix.LiveView.Rendered.t()
  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="h-full">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()}/>
        <title>Dala Dev</title>
        <link rel="icon" href="data:,"/>
        <script src="https://cdn.tailwindcss.com"></script>
        <script src="/assets/phoenix/phoenix.min.js"></script>
        <script src="/assets/plv/phoenix_live_view.js"></script>
        <script>
          const Hooks = {};

          // Keeps the log panel pinned to bottom unless the user scrolls up.
          Hooks.ScrollBottom = {
            mounted()      { this.atBottom = true; this.scrollToBottom(); },
            beforeUpdate() {
              const el = this.el;
              this.atBottom = el.scrollTop + el.clientHeight >= el.scrollHeight - 20;
            },
            updated()      { if (this.atBottom) this.scrollToBottom(); },
            scrollToBottom() { this.el.scrollTop = this.el.scrollHeight; }
          };

          // Draggable divider between device logs and Elixir logs.
          // Dragging left widens the Elixir pane; dragging right narrows it.
          Hooks.ResizableDivider = {
            mounted() {
              const elixirPane = this.el.nextElementSibling;
              const container  = this.el.parentElement;
              const minWidth   = 180;

              this.onMouseDown = (e) => {
                e.preventDefault();
                const startX     = e.clientX;
                const startWidth = elixirPane.offsetWidth;

                const onMouseMove = (e) => {
                  const delta    = startX - e.clientX;
                  const maxWidth = container.offsetWidth - 300;
                  const newWidth = Math.max(minWidth, Math.min(startWidth + delta, maxWidth));
                  elixirPane.style.width     = newWidth + 'px';
                  elixirPane.style.flexShrink = '0';
                  elixirPane.style.flexBasis  = newWidth + 'px';
                };

                const onMouseUp = () => {
                  document.removeEventListener('mousemove', onMouseMove);
                  document.removeEventListener('mouseup',  onMouseUp);
                  document.body.style.cursor     = '';
                  document.body.style.userSelect = '';
                };

                document.addEventListener('mousemove', onMouseMove);
                document.addEventListener('mouseup',   onMouseUp);
                document.body.style.cursor     = 'col-resize';
                document.body.style.userSelect = 'none';
              };

              this.el.addEventListener('mousedown', this.onMouseDown);
            },
            destroyed() {
              this.el.removeEventListener('mousedown', this.onMouseDown);
            }
          };

          let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
            hooks: Hooks,
            params: { _csrf_token: document.querySelector("meta[name='csrf-token']").getAttribute("content") }
          });
          liveSocket.connect();
        </script>
        <style>
          .log-line { font-family: ui-monospace, monospace; font-size: 0.75rem; }
          .log-E { color: #f87171; }
          .log-W { color: #fbbf24; }
          .log-I { color: #86efac; }
          .log-D { color: #94a3b8; }
          .log-dala { color: #a78bfa; font-weight: 600; }
          #log-container { scroll-behavior: smooth; }
        </style>
      </head>
      <body class="h-full bg-zinc-950 text-zinc-200 flex flex-col">
        {@inner_content}
      </body>
    </html>
    """
  end

  @spec app(map()) :: Phoenix.LiveView.Rendered.t()
  def app(assigns) do
    ~H"""
    {@inner_content}
    """
  end
end
