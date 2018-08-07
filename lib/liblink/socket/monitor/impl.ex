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
  use Liblink.Logger

  alias Liblink.Nif
  alias Liblink.Socket.Device
  alias Liblink.Socket.Sendmsg
  alias Liblink.Socket.Recvmsg

  @type state_t :: %{procs: map, socks: map}

  @spec init() :: {:ok, state_t}
  def init() do
    {:ok, %{procs: Map.new(), socks: Map.new()}}
  end

  @spec new_device(state_t, (pid -> Nif.socket_t())) ::
          {:reply, {:ok, Device.t()}, state_t} | {:reply, :error, state_t}
  def new_device(state, new_sockfn) when is_function(new_sockfn, 1) do
    {:ok, recvmsg_pid} = Recvmsg.start()
    {:ok, sendmsg_pid} = Sendmsg.start()
    recvmsg_tag = Process.monitor(recvmsg_pid)
    sendmsg_tag = Process.monitor(sendmsg_pid)

    case new_sockfn.(recvmsg_pid) do
      {:ok, socket} ->
        new_socks = Map.new([{recvmsg_tag, recvmsg_pid}, {sendmsg_tag, sendmsg_pid}])
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

  @spec stats(state_t) :: {:reply, map, state_t}
  def stats(state) do
    stats = %{socks_count: Enum.count(state.socks), procs_count: Enum.count(state.procs)}

    {:reply, stats, state}
  end

  @spec stop(state_t) :: state_t
  def stop(state) do
    state.socks
    |> Enum.each(fn {socket, procs} ->
      procs
      |> Map.values()
      |> Enum.each(&Liblink.Socket.Shared.halt(&1, 100))

      Nif.term(socket)
    end)

    {:ok, new_state} = init()
    new_state
  end

  @spec down(state_t, reference) :: {:noreply, state_t}
  def down(state, tag) do
    case Map.fetch(state.procs, tag) do
      {:ok, sock} ->
        temp_state =
          state
          |> Map.update!(:procs, &Map.delete(&1, tag))
          |> Map.update!(:socks, fn socks ->
            Map.update!(socks, sock, &Map.delete(&1, tag))
          end)

        procs = Map.fetch!(temp_state.socks, sock)

        new_state =
          if Enum.empty?(procs) do
            Nif.term(sock)

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
