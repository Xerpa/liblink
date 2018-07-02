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
    Impl.init()
  end

  @impl true
  def terminate(_reason, _state) do
    # TODO:term_all_sockets
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

      message ->
        _ = Logger.warn("unexpected message", metadata: [data: [message: message]])
        {:noreply, state}
    end
  end
end
