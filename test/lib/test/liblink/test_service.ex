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
end
