defmodule Mix.Tasks.Dala.Release.AndroidTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Dala.Release.Android

  # ── format_size/1 ──────────────────────────────────────────────────────────

  describe "format_size/1" do
    test "bytes" do
      assert Android.format_size(0) == "0B"
      assert Android.format_size(512) == "512B"
      assert Android.format_size(1023) == "1023B"
    end

    test "kilobytes" do
      assert Android.format_size(1024) == "1.0K"
      assert Android.format_size(1536) == "1.5K"
      assert Android.format_size(10 * 1024) == "10.0K"
    end

    test "megabytes" do
      assert Android.format_size(1024 * 1024) == "1.0M"
      assert Android.format_size(2 * 1024 * 1024) == "2.0M"
      assert Android.format_size(1_500_000) == "1.4M"
    end
  end
end
