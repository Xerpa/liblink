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

defmodule Liblink.Socket.Recvmsg.Transition do
  alias Liblink.Socket.Recvmsg.RecvState
  alias Liblink.Socket.Recvmsg.SubsState

  require Logger

  @type consumer_t :: {atom, atom, list} | {atom, atom} | atom | pid | (iolist -> term)

  @spec init_to_recv(Device.t(), map) ::
          {:cont, :ok, {RecvState, %{device: Device.t(), mqueue: term}}}
  def init_to_recv(device, data) do
    data =
      data
      |> Map.put(:device, device)
      |> Map.put(:mqueue, :queue.new())

    {:cont, :ok, {RecvState, data}}
  end

  @spec recv_to_consume(consumer_t, map) ::
          {:cont, {:erro, :bad_consumer}, {RecvState, map}}
          | {:cont, :ok, {SendState, map}}
  def recv_to_consume(consumer, data) do
    _ = Logger.info("recvmsg-fsm: recv -> consume")

    consumer =
      case consumer do
        {name, node} when is_atom(name) and is_atom(node) ->
          %{pid_or_fun: consumer, tag: Process.monitor(consumer)}

        {module, function, args} when is_atom(module) and is_atom(function) and is_list(args) ->
          %{pid_or_fun: consumer}

        name_or_pid when is_atom(name_or_pid) or is_pid(name_or_pid) ->
          %{pid_or_fun: consumer, tag: Process.monitor(consumer)}

        anon_fn when is_function(anon_fn, 1) ->
          %{pid_or_fun: consumer}
      end

    n_data = Map.put(data, :consumer, consumer)

    case Map.fetch(consumer, :tag) do
      :error ->
        n_data
        |> recv_to_consume__halt_polls()
        |> recv_to_consume__flush_messages()

      {:ok, tag} ->
        receive do
          {:DOWN, ^tag, :process, _object, _reason} ->
            Process.demonitor(tag)
            {:cont, {:error, :bad_consumer}, {RecvState, data}}
        after
          0 ->
            n_data
            |> recv_to_consume__halt_polls()
            |> recv_to_consume__flush_messages()
        end
    end
  end

  @spec consume_to_recv(iolist, map) :: {:cont, :ok, {RecvState, map}}
  def consume_to_recv(message, data) do
    _ = Logger.info("recvmsg-fsm: consume -> recv")

    mqueue = :queue.in(message, data.mqueue)

    n_data =
      data
      |> Map.delete(:consumer)
      |> Map.put(:mqueue, mqueue)

    {:cont, :ok, {RecvState, n_data}}
  end

  @spec consume_to_recv(map) :: {:cont, :ok, {RecvState, map}}
  def consume_to_recv(data) do
    _ = Logger.info("recvmsg-fsm: consume -> recv")

    n_data = Map.delete(data, :consumer)

    {:cont, :ok, {RecvState, n_data}}
  end

  @spec recv_to_consume__halt_polls(map) :: map
  defp recv_to_consume__halt_polls(data) do
    case Map.fetch(data, :poll) do
      :error ->
        data

      {:ok, polls} ->
        Enum.reduce(polls, data, fn {tag, _}, data ->
          {:cont, :ok, {RecvState, data}} = RecvState.halt_poll(tag, data)
          data
        end)
    end
  end

  @spec recv_to_consume__flush_messages(map) ::
          {:cont, :ok, {RecvState, map}} | {:cont, :ok, {SubState, map}}
  defp recv_to_consume__flush_messages(data) do
    case :queue.out(data.mqueue) do
      {:empty, _mqueue} ->
        {:cont, :ok, {SubsState, data}}

      {{:value, message}, mqueue} ->
        case SubsState.on_liblink_message(message, data) do
          {:cont, :ok, {SubsState, data}} ->
            recv_to_consume__flush_messages(%{data | mqueue: mqueue})

          transition = {:cont, :ok, _next_state} ->
            transition
        end
    end
  end
end
