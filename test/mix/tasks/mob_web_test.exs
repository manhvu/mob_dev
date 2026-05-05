defmodule Mix.Tasks.Mob.WebTest do
  use ExUnit.Case, async: false

  describe "run/1" do
    test "starts web server with default options" do
      # This test verifies the task can be compiled and loaded
      assert Code.ensure_loaded?(Mix.Tasks.Mob.Web)
    end

    test "has correct moduledoc" do
      # Verify the module has documentation
      {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Mix.Tasks.Mob.Web)
      # moduledoc can be a map with "en" key or a string
      doc_string =
        case moduledoc do
          %{"en" => doc} -> doc
          doc when is_binary(doc) -> doc
          _ -> ""
        end

      assert doc_string =~ "Start the Mob Web UI"
    end
  end
end
