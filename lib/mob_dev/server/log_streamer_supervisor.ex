defmodule MobDev.Server.LogStreamerSupervisor do
  @moduledoc """
  Isolated supervisor for LogStreamer.

  LogStreamer opens OS ports (adb logcat, xcrun) that can exit unexpectedly,
  causing crashes. Keeping it under its own supervisor means those crashes
  never bubble up to restart LogBuffer, the Endpoint, or the LiveView.
  """
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  @spec init(term()) :: {:ok, tuple()}
  def init(_opts) do
    children = [MobDev.Server.LogStreamer]
    # Allow frequent restarts — port exits are normal, not bugs.
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 50, max_seconds: 10)
  end
end
