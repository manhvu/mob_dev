defmodule MobDev.Utils do
  @moduledoc """
  Shared utility functions used across the mob_dev codebase.

  This module centralizes common operations to reduce duplication
  and ensure consistent behavior across modules.
  """

  @doc """
  Compiles a regex pattern with the given options.

  Centralizes regex compilation to avoid duplicating `Regex.compile!/2` calls
  and provides a single place to handle compilation errors.

  ## Examples

      iex> MobDev.Utils.compile_regex("hello\\s+world")
      ~r/hello\\s+world/

  """
  @spec compile_regex(String.t(), String.t()) :: Regex.t()
  def compile_regex(pattern, opts \\ "") do
    case Regex.compile(pattern, opts) do
      {:ok, regex} ->
        regex

      {:error, {reason, position}} ->
        raise "Invalid regex pattern: #{inspect(pattern)}, " <>
                "error: #{reason} at position #{position}"
    end
  end

  @doc """
  Safely runs an ADB command with timeout protection.

  Returns `{:ok, output}` on success, `{:error, reason}` on failure.

  ## Options

  - `:timeout` - timeout in milliseconds (default: 8000)
  - `:stderr_to_stdout` - whether to merge stderr (default: true)
  """
  @spec run_adb_with_timeout(list(String.t()), keyword()) :: {:ok, String.t()} | {:error, term()}
  def run_adb_with_timeout(args, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 8000)
    stderr_to_stdout = Keyword.get(opts, :stderr_to_stdout, true)
    cmd = Enum.join(["adb" | args], " ")

    case System.cmd("sh", ["-c", "timeout #{div(timeout, 1000)} #{cmd}"],
           stderr_to_stdout: stderr_to_stdout
         ) do
      {output, 0} -> {:ok, String.trim(output)}
      {_output, 124} -> {:error, :timeout}
      {output, _code} -> {:error, String.trim(output)}
    end
  end

  @doc """
  Runs an ADB command for a specific device with timeout.

  Convenience wrapper that prepends `-s <serial>` to the arguments.
  """
  @spec run_adb_for_device(String.t(), list(String.t()), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def run_adb_for_device(serial, args, opts \\ []) do
    run_adb_with_timeout(["-s", serial | args], opts)
  end

  @doc """
  Checks if ADB is available in the system PATH.
  """
  @spec adb_available?() :: boolean()
  def adb_available? do
    command_available?("adb")
  end

  @doc """
  Parses ADB devices output into a list of device identifiers.

  Expects output from `adb devices` command.
  """
  @spec parse_adb_devices_output(String.t()) :: [String.t()]
  def parse_adb_devices_output(output) do
    output
    |> String.split("\n")
    |> Enum.drop(1)
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Enum.map(&String.split(&1, "\t"))
    |> Enum.map(&List.first/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Checks if a command is available in the system PATH.
  """
  @spec command_available?(String.t()) :: boolean()
  def command_available?(cmd) do
    System.find_executable(cmd) != nil
  end

  @doc """
  Ensures a directory exists, creating it if necessary.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec ensure_dir(String.t()) :: :ok | {:error, term()}
  def ensure_dir(path) do
    case File.mkdir_p(path) do
      :ok -> :ok
      {:error, _} = err -> err
    end
  end

  @doc """
  Formats a byte size into a human-readable string.
  """
  @spec format_bytes(non_neg_integer()) :: String.t()
  def format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  def format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  def format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end
