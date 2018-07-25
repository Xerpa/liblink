# Copyright 2018 (c) Xerpa
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Liblink.Socket.Recvmsg.RecvState do
  use Liblink.Socket.Recvmsg.Fsm

  alias Liblink.Socket.Recvmsg.Transition

  @impl true
  def recvmsg(data) do
    case :queue.out(data.mqueue) do
      {{:value, msg}, mqueue} ->
        {:cont, {:ok, Enum.reverse(msg)}, {__MODULE__, %{data | mqueue: mqueue}}}

      {:empty, _mqueue} ->
        {:cont, {:error, :empty}, {__MODULE__, data}}
    end
  end

  @impl true
  def poll(pid, data) do
    tag = :erlang.make_ref()
    item = %{tag => pid}

    data =
      if :queue.is_empty(data.mqueue) do
        Map.update(data, :poll, item, &Map.merge(item, &1))
      else
        notify_poll({tag, pid}, :data)
        data
      end

    {:cont, {:ok, tag}, {__MODULE__, data}}
  end

  @impl true
  def halt_poll(tag, data) do
    {mpid, data} =
      Map.get_and_update(data, :poll, fn poll ->
        if is_map(poll) do
          Map.pop(poll, tag)
        else
          {nil, %{}}
        end
      end)

    unless is_nil(mpid) do
      notify_poll({tag, mpid}, :timeout)
    end

    {:cont, :ok, {__MODULE__, data}}
  end

  @impl true
  def consume(consumer, data) do
    Transition.recv_to_consume(consumer, data)
  end

  @impl true
  def on_liblink_message(message, data) do
    mqueue = :queue.in(message, data.mqueue)

    {pollers, data} = Map.pop(data, :poll)

    if pollers do
      Enum.each(pollers, &notify_poll(&1, :data))
    end

    {:cont, :ok, {__MODULE__, %{data | mqueue: mqueue}}}
  end

  @spec notify_poll({reference, pid}, :data | :timeout) :: :ok
  defp notify_poll({tag, pid}, signal) do
    Process.send(pid, {tag, signal}, [])
  end
end
