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

defmodule Liblink.Socket.Recvmsg do
  use GenServer

  alias Liblink.Socket.Shared
  alias Liblink.Socket.Recvmsg.Impl

  require Logger

  @dialyzer [:unknown]

  @opaque state_t :: map

  @spec start() :: {:ok, pid}
  def start() do
    GenServer.start(__MODULE__, [])
  end

  @impl true
  def init(_args) do
    Impl.init()
  end

  @doc """
  halt the recvmsg thread
  """
  @spec halt(pid, integer | :infinity) :: :ok
  def halt(pid, timeout \\ 5_000), do: Shared.halt(pid, timeout)

  @doc """
  halt the current consumer
  """
  def halt_consumer(pid, timeout \\ 5_000) do
    GenServer.call(pid, {:halt, :consumer}, timeout)
  end

  @doc false
  def attach(pid, device, timeout \\ 5_000) do
    GenServer.call(pid, {:attach, device}, timeout)
  end

  def poll(pid, timeout) do
    GenServer.call(pid, {:poll, timeout}, timeout)
  end

  def recvmsg(pid, timeout) do
    GenServer.call(pid, :recvmsg, timeout)
  end

  def consume(pid, consumer, timeout) do
    GenServer.call(pid, {:consume, consumer}, timeout)
  end

  @impl true
  def handle_call(message, {from, _}, state) do
    case message do
      :halt ->
        Impl.halt(:sync, state)

      {:halt, :consumer} ->
        Impl.halt_consumer(:sync, state)

      {:halt, :poll, tag} ->
        Impl.halt_poll(tag, :sync, state)

      {:attach, device} ->
        Impl.attach(device, :sync, state)

      {:poll, timeout} ->
        Impl.poll(timeout, from, :sync, state)

      :recvmsg ->
        Impl.recvmsg(:sync, state)

      {:consume, consumer} ->
        Impl.consume(consumer, :sync, state)

      message ->
        _ =
          Logger.warn(
            "[socket.recvmsg] ignoring unexpected message",
            metadata: [data: [message: message]]
          )

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(message, state) do
    case message do
      :halt ->
        Impl.halt(:async, state)

      {:halt, :poll, tag} ->
        Impl.halt_poll(tag, :async, state)

      {:halt, :consumer} ->
        Impl.halt_consumer(:async, state)

      message ->
        _ =
          Logger.warn(
            "[socket.recvmsg] ignoring unexpected message",
            metadata: [data: [message: message]]
          )

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(message, state) do
    case message do
      {:halt, :poll, tag} ->
        Impl.halt_poll(tag, :async, state)

      {:liblink_message, message} ->
        Impl.on_liblink_message(message, :async, state)

      {:DOWN, _ta, :process, _object, _reason} ->
        Impl.on_monitor_message(message, :async, state)

      message ->
        _ =
          Logger.warn(
            "[socket.recvmsg] ignoring unexpected message",
            metadata: [data: [message: message]]
          )

        {:noreply, state}
    end
  end
end
