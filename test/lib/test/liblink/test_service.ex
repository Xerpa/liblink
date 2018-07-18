defmodule Test.Liblink.TestService do
  alias Liblink.Data.Message

  def echo(%{payload: {:echo, echo}}) do
    echo
  end

  def echo(request) do
    {:ok, request}
  end

  def ping(%{payload: :ping}) do
    {:ok, Message.new(:pong)}
  end

  def ping(_) do
    {:error, Message.new(:error)}
  end

  def misbehaving(_message) do
    :misbehaving
  end

  def exception(%{payload: message}) when is_binary(message) do
    raise(RuntimeError, message: message)
  end
end
