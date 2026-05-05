defmodule DalaDev.Error do
  @moduledoc """
  Standardized error handling for the dala_dev codebase.

  Provides consistent error types and helper functions to ensure
  uniform error reporting across all modules.
  """

  @type t :: {:error, reason :: term()} | {:error, module :: atom(), reason :: term()}

  @doc """
  Creates a standardized error tuple with optional module context.
  """
  @spec new(term()) :: {:error, term()}
  def new(reason), do: {:error, reason}

  @spec new(atom(), term()) :: {:error, atom(), term()}
  def new(module, reason), do: {:error, module, reason}

  @doc """
  Formats an error for user-friendly display.
  """
  @spec format({:error, term()}) :: String.t()
  def format({:error, reason}), do: format_reason(reason)

  def format({:error, module, reason}) do
    "[#{inspect(module)}] #{format_reason(reason)}"
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: inspect(reason)

  @doc """
  Wraps a function call with standardized error handling.
  """
  @spec wrap(term(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def wrap(context, fun) do
    try do
      fun.()
    rescue
      e -> {:error, {context, Exception.message(e)}}
    end
  end
end
