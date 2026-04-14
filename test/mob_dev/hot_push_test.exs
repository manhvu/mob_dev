defmodule MobDev.HotPushTest do
  use ExUnit.Case, async: true

  alias MobDev.HotPush

  # ── snapshot_beams/0 ─────────────────────────────────────────────────────────

  describe "snapshot_beams/0" do
    test "returns a non-empty map" do
      assert map_size(HotPush.snapshot_beams()) > 0
    end

    test "all keys are .beam paths" do
      HotPush.snapshot_beams()
      |> Map.keys()
      |> Enum.each(fn path -> assert String.ends_with?(path, ".beam") end)
    end

    test "all values are integer mtimes" do
      HotPush.snapshot_beams()
      |> Map.values()
      |> Enum.each(fn mtime -> assert is_integer(mtime) end)
    end
  end

  # ── push_changed/2 ───────────────────────────────────────────────────────────

  describe "push_changed/2" do
    test "returns {0, []} when nothing changed since snapshot" do
      snapshot = HotPush.snapshot_beams()
      # Snapshot taken, no compile ran — nothing should differ.
      assert {0, []} = HotPush.push_changed([], snapshot)
    end

    test "detects beam files not in snapshot (empty snapshot)" do
      beam_count = Path.wildcard("_build/dev/lib/*/ebin/*.beam") |> length()
      # Empty snapshot means every existing beam is "new".
      {pushed, failed} = HotPush.push_changed([], %{})
      assert failed == []
      assert pushed == beam_count
    end

    test "does not push files that haven't changed" do
      snapshot = HotPush.snapshot_beams()
      # Immediately re-check — mtimes are identical, so nothing should be pushed.
      {pushed, _} = HotPush.push_changed([], snapshot)
      assert pushed == 0
    end

    test "returns ok with no nodes (no RPC attempted)" do
      snapshot = HotPush.snapshot_beams()
      # Even with an empty node list, must not raise.
      assert {_pushed, _failed} = HotPush.push_changed([], snapshot)
    end
  end

  # ── push_all/1 ───────────────────────────────────────────────────────────────

  describe "push_all/1" do
    test "returns {count, []} with no nodes" do
      {pushed, failed} = HotPush.push_all([])
      assert is_integer(pushed)
      assert failed == []
    end

    test "push count matches number of beam files in _build" do
      beam_count = Path.wildcard("_build/dev/lib/*/ebin/*.beam") |> length()
      {pushed, _} = HotPush.push_all([])
      assert pushed == beam_count
    end
  end

end
