defmodule DalaDev.Server.LogStreamerTest do
  use ExUnit.Case, async: true

  alias DalaDev.Server.LogStreamer

  describe "parse_line/2" do
    test "parses android logcat brief format" do
      line = "I/DalaBeam( 1234): Starting BEAM with module=dala_demo, argc=18"
      result = LogStreamer.parse_line(line, "ZY22K6BSJM")

      assert result.level == "I"
      assert result.tag == "DalaBeam"
      assert result.message == "Starting BEAM with module=dala_demo, argc=18"
      assert result.serial == "ZY22K6BSJM"
      assert result.dala == true
    end

    test "marks dala tags as dala: true" do
      line = "E/DalaNif( 999): enif_get_long failed"
      result = LogStreamer.parse_line(line, "serial")
      assert result.dala == true
      assert result.level == "E"
      assert result.tag == "DalaNif"
    end

    test "marks non-dala tags as dala: false" do
      line = "I/ActivityManager( 100): Start proc com.dala.demo"
      result = LogStreamer.parse_line(line, "serial")
      assert result.dala == false
      assert result.tag == "ActivityManager"
    end

    test "marks Elixir tag as dala: true" do
      line = "I/Elixir  (24617): Tap me pressed — count is now 1"
      result = LogStreamer.parse_line(line, "serial")
      assert result.dala == true
      assert result.tag == "Elixir"
      assert result.level == "I"
      assert result.message == "Tap me pressed — count is now 1"
    end

    test "parses error level" do
      line = "E/AndroidRuntime(5678): FATAL EXCEPTION: main"
      result = LogStreamer.parse_line(line, "serial")
      assert result.level == "E"
    end

    test "parses warning level" do
      line = "W/System  ( 111): ClassLoader referenced unknown path"
      result = LogStreamer.parse_line(line, "serial")
      assert result.level == "W"
    end

    test "falls back gracefully for unparsed lines" do
      app = Mix.Project.config()[:app] |> to_string()
      line = "[2024-01-01 12:00:00] Some iOS syslog line from #{app}"
      result = LogStreamer.parse_line(line, "sim-udid")

      assert result.serial == "sim-udid"
      assert result.level == "I"
      assert result.tag == nil
      assert result.message == line
      # contains the current app name
      assert result.dala == true
    end

    test "unparsed line without dala content is dala: false" do
      result = LogStreamer.parse_line("some random system log line", "serial")
      assert result.dala == false
    end

    test "iOS syslog line with DalaDemo process is dala: true" do
      line = "2026-04-14 07:45:04.099 DalaDemo[1234:5678] [DalaBeam] dala_start_beam: starting"
      result = LogStreamer.parse_line(line, "sim-udid")
      assert result.dala == true
    end

    test "iOS syslog Logger output with current app name is dala: true" do
      app_camel = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()

      line =
        "2026-04-14 07:45:04.099 #{app_camel}[1234:5678] [info] Tap me pressed — count is now 1"

      result = LogStreamer.parse_line(line, "sim-udid")
      assert result.dala == true
    end

    test "iOS syslog DalaNIF tag (all caps) is dala: true" do
      line = "2026-04-14 07:45:04.099 DalaDemo[1234:5678] [DalaNIF] set_root called"
      result = LogStreamer.parse_line(line, "sim-udid")
      assert result.dala == true
    end

    test "includes timestamp" do
      result = LogStreamer.parse_line("I/Tag(1): msg", "serial")
      assert result.ts =~ ~r/^\d{2}:\d{2}:\d{2}$/
    end

    test "handles tag with extra spaces" do
      line = "D/DalaBridge(  42): setRoot called"
      result = LogStreamer.parse_line(line, "serial")
      assert result.tag == "DalaBridge"
      assert result.dala == true
    end
  end
end
