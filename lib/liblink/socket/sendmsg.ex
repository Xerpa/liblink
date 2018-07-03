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

defmodule Liblink.Socket.Sendmsg do
  use GenServer

  alias Liblink.Socket.Sendmsg.Impl

  require Logger

  @dialyzer [:unknown]

  @doc """
  initializes the sendmsg thread.
  """
  @spec start() :: {:ok, pid}
  def start() do
    GenServer.start(__MODULE__, [])
  end

  @impl true
  def init(_args) do
    Impl.init()
  end

  @doc """
  halt the sendmsg thread.
  """
  def halt(pid, timeout \\ 5_000) do
    tag = Process.monitor(pid)
    GenServer.cast(pid, :halt)

    receive do
      {:DOWN, ^tag, :process, _pid, _reason} ->
        Process.demonitor(tag)
        :ok
    after
      timeout ->
        Process.demonitor(tag)
        Process.exit(pid, :kill)
        :ok
    end
  end

  @doc false
  def attach(pid, device, timeout \\ 5_000) do
    GenServer.call(pid, {:attach, device}, timeout)
  end

  @doc """
  sends a synchronous message. the server will try to meet the timeout
  deadline and will discarde expired messages.

  this function uses `GenServer.call` to perform this request and
  catches exit signals. this should be usually fine as we wait a
  little longer for a reply message. however, in the rare event we
  miss the reply message the client must in this case be prepared to
  discard garbage messages that are two-element tuples with a
  reference at the first element. refer to `GenServer.call`
  documentation for more information about this.
  """
  def sendmsg(pid, message, :infinity) do
    GenServer.call(pid, {:sendmsg, message}, :infinity)
  end

  def sendmsg(pid, message, timeout_in_ms) when is_integer(timeout_in_ms) do
    timeout = :erlang.convert_time_unit(timeout_in_ms, :millisecond, :native)
    deadline = :erlang.monotonic_time() + timeout

    try do
      GenServer.call(pid, {:sendmsg, message, deadline}, timeout_in_ms + 100)
    catch
      :exit, {:timeout, {GenServer, :call, _}} ->
        {:error, :timeout}
    end
  end

  @doc """
  send an asynchornous message. notice there are no guarantees about
  message delivery. if you need confirmation use `sendmsg/3`.
  """
  def sendmsg_async(pid, message, :infinity) do
    GenServer.cast(pid, {:sendmsg, message})
  end

  def sendmsg_async(pid, message, timeout_in_ms) when is_integer(timeout_in_ms) do
    timeout = :erlang.convert_time_unit(timeout_in_ms, :millisecond, :native)
    deadline = :erlang.monotonic_time() + timeout

    GenServer.cast(pid, {:sendmsg, message, deadline})
  end

  @impl true
  def handle_call(message, _from, state) do
    case message do
      :halt ->
        Impl.halt(:sync, state)

      {:attach, device} ->
        Impl.attach(device, :sync, state)

      {:sendmsg, message} ->
        Impl.sendmsg(message, :sync, state)

      {:sendmsg, message, deadline} ->
        Impl.sendmsg(message, deadline, :sync, state)

      message ->
        _ =
          Logger.warn(
            "[socket.sendmsg] ignoring unexpected message",
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

      {:sendmsg, message} ->
        Impl.sendmsg(message, :async, state)

      {:sendmsg, message, deadline} ->
        Impl.sendmsg(message, deadline, :async, state)

      message ->
        _ =
          Logger.warn(
            "[socket.sendmsg] ignoring unexpected message",
            metadata: [data: [message: message]]
          )

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(message, state) do
    _ =
      Logger.warn(
        "[socket.sendmsg] ignoring unexpected message",
        metadata: [data: [message: message]]
      )

    {:noreply, state}
  end
end
