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

defmodule Liblink.Socket.Monitor.Impl do
  alias Liblink.Nif
  alias Liblink.Socket.Device
  alias Liblink.Socket.Sendmsg
  alias Liblink.Socket.Recvmsg

  require Logger

  @opaque state :: %{procs: MapSet.t(), socks: map}

  @spec init() :: {:ok, state}
  def init() do
    {:ok, %{procs: MapSet.new(), socks: Map.new()}}
  end

  @spec new_device(state, (pid -> Nif.t())) ::
          {:reply, {:ok, Device.t()}, state} | {:reply, :error, state}
  def new_device(state, new_sockfn) when is_function(new_sockfn, 1) do
    {:ok, recvmsg_pid} = Recvmsg.start()
    {:ok, sendmsg_pid} = Sendmsg.start()
    recvmsg_tag = Process.monitor(recvmsg_pid)
    sendmsg_tag = Process.monitor(sendmsg_pid)

    case new_sockfn.(recvmsg_pid) do
      {:ok, socket} ->
        new_socks = MapSet.new([recvmsg_tag, sendmsg_tag])
        new_procs = Map.new([{recvmsg_tag, socket}, {sendmsg_tag, socket}])

        new_state =
          state
          |> Map.update!(:socks, &Map.put(&1, socket, new_socks))
          |> Map.update!(:procs, &Map.merge(&1, new_procs))

        case Device.new(socket, recvmsg_pid, sendmsg_pid) do
          {:ok, device} ->
            {:reply, {:ok, device}, new_state}

          error ->
            Recvmsg.halt(recvmsg_pid)
            Sendmsg.halt(sendmsg_pid)

            {:reply, error, new_state}
        end

      _otherwise ->
        Recvmsg.halt(recvmsg_pid)
        Sendmsg.halt(sendmsg_pid)

        {:reply, :error, state}
    end
  end

  def down(state, tag) do
    case Map.fetch(state.procs, tag) do
      {:ok, sock} ->
        temp_state =
          state
          |> Map.update!(:procs, &Map.delete(&1, tag))
          |> Map.update!(:socks, fn socks ->
            Map.update!(socks, sock, &MapSet.delete(&1, tag))
          end)

        procs = Map.fetch!(temp_state.socks, sock)

        new_state =
          if Enum.empty?(procs) do
            {:ok, _pid} = Task.start_link(fn -> Nif.term(sock) end)

            Map.update!(temp_state, :socks, &Map.delete(&1, sock))
          else
            temp_state
          end

        {:noreply, new_state}

      :error ->
        {:noreply, state}
    end
  end
end
