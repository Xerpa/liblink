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

defmodule Liblink.Socket.Recvmsg.Impl do
  alias Liblink.Socket.Device
  alias Liblink.Socket.Recvmsg.Fsm

  require Logger

  @moduledoc false

  @opaque state_t :: map()

  @type call_mode :: :sync | :async

  @type consumer_t :: {atom, atom, list} | {atom, atom} | atom | pid | (iodata -> term)

  @spec init() :: {:ok, state_t}
  def init() do
    {:ok, %{fsm: Fsm.new()}}
  end

  @spec halt(call_mode, state_t) :: {:reply, :ok, state_t}
  def halt(mode, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.halt(data) end, mode, state)
  end

  @spec attach(Device.t(), call_mode, state_t) ::
          {:reply, :ok, state_t} | {:reply, {:error, :badstate}, state_t}
  def attach(device, mode, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.attach(device, data) end, mode, state)
  end

  @spec recvmsg(:sync, state_t) ::
          {:reply, {:ok, iodata}, state_t}
          | {:reply, {:error, :timeout}, state_t}
          | {:reply, {:error, :empty}, state_t}
          | {:reply, {:ok, :badstate}, state_t}
  def recvmsg(:sync, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.recvmsg(data) end, :sync, state)
  end

  @spec poll(timeout, pid, :sync, state_t) ::
          {:reply, {:ok, reference}, state_t}
          | {:reply, {:error, :badstate}, state_t}
  def poll(timeout, pid, :sync, state) do
    {fsm, data} = state.fsm

    with reply = {:reply, {:ok, tag}, _data} when is_reference(tag) <-
           call_fsm(fn -> fsm.poll(pid, data) end, :sync, state) do
      _ =
        unless timeout == :infinity do
          Process.send_after(self(), {:halt, :poll, tag}, timeout)
        end

      reply
    end
  end

  @spec halt_poll(reference, call_mode, state_t) ::
          {:reply, :ok, state_t}
          | {:reply, {:error, :badstate}, state_t}
          | {:noreply, state_t}
  def halt_poll(tag, mode, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.halt_poll(tag, data) end, mode, state)
  end

  @spec consume(consumer_t, call_mode, state_t) ::
          {:reply, :ok, state_t}
          | {:reply, {:error, :badstate}, state_t}
          | {:noreply, state_t}
  def consume(consumer, mode, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.consume(consumer, data) end, mode, state)
  end

  @spec halt_consumer(call_mode, state_t) ::
          {:reply, :ok, state_t}
          | {:reply, {:error, :badstate}, state_t}
          | {:noreply, state_t}
  def halt_consumer(mode, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.halt_consumer(data) end, mode, state)
  end

  @spec on_liblink_message(iodata, :async, state_t) :: {:noreply, state_t}
  def on_liblink_message(message, :async, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.on_liblink_message(message, data) end, :async, state)
  end

  @spec on_monitor_message(
          {:DOWN, reference, :process, pid | {atom, atom}, atom},
          :async,
          state_t
        ) :: {:noreply, state_t}
  def on_monitor_message(message, :async, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.on_monitor_message(message, data) end, :async, state)
  end

  @spec call_fsm((() -> Fsm.fsm_return()), call_mode, state_t) ::
          {:noreply, state_t}
          | {:reply, term, state_t}
          | {:stop, :normal, state_t}
          | {:stop, :normal, term, state_t}
  defp call_fsm(event_fn, :async, state) do
    case event_fn.() do
      {:cont, next_state} ->
        {:noreply, %{state | fsm: next_state}}

      {:cont, _term, next_state} ->
        {:noreply, %{state | fsm: next_state}}

      {:halt, next_state} ->
        {:stop, :normal, %{state | fsm: next_state}}

      {:halt, _term, next_state} ->
        {:stop, :normal, %{state | fsm: next_state}}
    end
  end

  defp call_fsm(event_fn, :sync, state) do
    case event_fn.() do
      {:cont, next_state} ->
        {:noreply, nil, %{state | fsm: next_state}}

      {:cont, term, next_state} ->
        {:reply, term, %{state | fsm: next_state}}

      {:halt, next_state} ->
        {:stop, :normal, nil, %{state | fsm: next_state}}

      {:halt, term, next_state} ->
        {:stop, :normal, term, %{state | fsm: next_state}}
    end
  end
end
