defmodule Mix.Tasks.Dala.WatchStopTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @pid_file Mix.Tasks.Dala.Watch.pid_file()

  setup do
    on_exit(fn -> File.rm(@pid_file) end)
    :ok
  end

  describe "run/1" do
    test "prints not-running message when no PID file exists" do
      File.rm(@pid_file)
      output = capture_io(fn -> Mix.Tasks.Dala.WatchStop.run([]) end)
      assert output =~ "not running"
    end

    test "kills the process, removes PID file, and prints confirmation" do
      # Open a port to get a real killable OS process
      port = Port.open({:spawn, "sleep 60"}, [:binary, :exit_status])
      {:os_pid, os_pid} = Port.info(port, :os_pid)

      File.mkdir_p!(Path.dirname(@pid_file))
      File.write!(@pid_file, to_string(os_pid))

      output = capture_io(fn -> Mix.Tasks.Dala.WatchStop.run([]) end)

      assert output =~ "stopped"
      assert output =~ to_string(os_pid)
      refute File.exists?(@pid_file)
      # port already closed — OS process was killed by watch_stop
      _ = port
    end

    test "removes PID file and prints warning when process no longer exists" do
      # Use a PID that is almost certainly not running
      File.mkdir_p!(Path.dirname(@pid_file))
      File.write!(@pid_file, "9999999")

      output = capture_io(fn -> Mix.Tasks.Dala.WatchStop.run([]) end)

      assert output =~ ~r/already exited|kill failed/i
      refute File.exists?(@pid_file)
    end

    test "PID file is cleaned up even when kill reports an error" do
      File.mkdir_p!(Path.dirname(@pid_file))
      File.write!(@pid_file, "9999999")

      capture_io(fn -> Mix.Tasks.Dala.WatchStop.run([]) end)

      refute File.exists?(@pid_file)
    end
  end
end
