defmodule Test.Liblink.Socket do
  use GenServer

  alias Test.Liblink.Socket.Impl

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_args) do
    {:ok, %{messages: []}}
  end

  def handle_call({:pop, timeout}, from, state) do
    Impl.pop({timeout, from}, state)
  end

  def handle_call(:pop, from, state) do
    Impl.pop({100, from}, state)
  end

  def handle_info({:liblink_message, message}, state) do
    Impl.recv(message, state)
  end

  def handle_info(message = {:pop, _}, state) do
    Impl.pop(message, state)
  end
end
