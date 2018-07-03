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

defmodule Liblink.Socket.Monitor do
  use GenServer

  alias Liblink.Socket.Monitor.Impl

  require Logger

  @spec start_link() :: {:ok, pid} | {:error, {:already_started, pid}}
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Process.flag(:trap_exit, true)

    Impl.init()
  end

  @spec stats :: map
  def stats() do
    GenServer.call(__MODULE__, :stats)
  end

  @impl true
  def terminate(reason, state) do
    Logger.debug("socket.monitor is terminated", metadata: [data: [reason: reason]])

    if Enum.empty?(state.procs) do
      :ok
    else
      Logger.info("closing all remaining sockets")
      Impl.stop(state)
    end
  end

  @spec new_device((pid -> {:ok, Nif.t()} | term)) :: {:ok, Device.t()} | {:error, term}
  def new_device(new_sockfn) do
    GenServer.call(__MODULE__, {:new_device, new_sockfn})
  end

  @impl true
  def handle_call(message, _from, state) do
    case message do
      {:new_device, new_sockfn} ->
        Impl.new_device(state, new_sockfn)

      :stats ->
        Impl.stats(state)

      message ->
        _ = Logger.warn("unexpected message", metadata: [data: [message: message]])
        {:reply, {:error, :badmsg}, state}
    end
  end

  @impl true
  def handle_info(message, state) do
    case message do
      {:DOWN, tag, :process, _pid, _reason} ->
        Impl.down(state, tag)

      {:EXIT, _from, reason} ->
        Logger.debug("socket.monitor is exiting", metadata: [data: [reason: reason]])

        state = Impl.stop(state)
        {:stop, reason, state}

      message ->
        _ = Logger.warn("unexpected message", metadata: [data: [message: message]])
        {:noreply, state}
    end
  end
end
