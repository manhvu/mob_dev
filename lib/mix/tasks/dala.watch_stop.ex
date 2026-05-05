defmodule Mix.Tasks.Dala.WatchStop do
  use Mix.Task

  @shortdoc "Stop a running mix dala.watch process"

  @moduledoc """
  Stops a running `mix dala.watch` process.

      mix dala.watch_stop

  Reads the PID written by `mix dala.watch` and sends SIGTERM.

  ## Under the hood

      pid = File.read!("_build/dala_watch.pid") |> String.trim()
      System.cmd("kill", [pid])   # SIGTERM
      File.rm("_build/dala_watch.pid")

  Equivalent to running `kill $(cat _build/dala_watch.pid)` in a terminal.
  """

  @impl Mix.Task
  def run(_args) do
    pid_file = Mix.Tasks.Dala.Watch.pid_file()

    case File.read(pid_file) do
      {:ok, contents} ->
        pid = String.trim(contents)

        case System.cmd("kill", [pid], stderr_to_stdout: true) do
          {_, 0} ->
            File.rm(pid_file)
            IO.puts("#{IO.ANSI.green()}dala.watch stopped (pid #{pid})#{IO.ANSI.reset()}")

          {out, _} ->
            File.rm(pid_file)

            IO.puts(
              "#{IO.ANSI.yellow()}kill failed (process may have already exited): #{String.trim(out)}#{IO.ANSI.reset()}"
            )
        end

      {:error, _} ->
        IO.puts(
          "#{IO.ANSI.yellow()}dala.watch is not running (no PID file found)#{IO.ANSI.reset()}"
        )
    end
  end
end
