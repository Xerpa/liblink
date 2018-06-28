defmodule Test.Liblink.Socket.Impl do
  def pop({:pop, {_, from}}, state = %{messages: [m | messages]}) do
    GenServer.reply(from, {:ok, m})
    {:noreply, %{state | messages: messages}}
  end

  def pop({:pop, {timeout, from}}, state) when timeout < 0 do
    GenServer.reply(from, {:error, :timeout})
    {:noreply, state}
  end

  def pop({:pop, {timeout, from}}, state) do
    Process.send_after(self(), {:pop, {timeout - 20, from}}, 20)
    {:noreply, state}
  end

  def pop({timeout, from}, state) do
    pop({:pop, {timeout, from}}, state)
  end

  def recv(message, state) do
    message = Enum.reverse(message)
    state = Map.update!(state, :messages, &(&1 ++ [message]))
    {:noreply, state}
  end
end
