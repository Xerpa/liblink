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

defmodule Liblink.Socket.Sendmsg.Impl do
  alias Liblink.Nif
  alias Liblink.Socket.Device
  alias Liblink.Socket.Sendmsg.Fsm

  @dialyzer [:unknown]

  @moduledoc false

  @opaque state_t :: map()

  @type call_mode :: :sync | :async

  @spec init() :: {:ok, state_t}
  def init() do
    {:ok, %{fsm: Fsm.new()}}
  end

  @spec halt(call_mode, state_t) ::
          {:stop, :normal, term, state_t()} | {:stop, :normal, state_t()}
  def halt(mode, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.halt(data) end, mode, state)
  end

  @spec attach(Device.t(), call_mode, state_t) ::
          {:reply, :ok, state_t()} | {:reply, {:error, :badstate}, state_t()}
  def attach(device, mode, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.attach(device, data) end, mode, state)
  end

  @spec sendmsg(iodata, integer(), call_mode, state_t) ::
          {:reply, Nif.sendmsg_return() | {:error, :timeout}, state_t()}
  def sendmsg(message, deadline, mode, state) do
    {fsm, data} = state.fsm

    call_fsm(fn -> fsm.sendmsg(message, deadline, data) end, mode, state)
  end

  @spec call_fsm((() -> Fsm.fsm_return()), call_mode, state_t()) ::
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
        {:noreply, %{state | fsm: next_state}}

      {:cont, term, next_state} ->
        {:reply, term, %{state | fsm: next_state}}

      {:halt, next_state} ->
        {:stop, :normal, nil, %{state | fsm: next_state}}

      {:halt, term, next_state} ->
        {:stop, :normal, term, %{state | fsm: next_state}}
    end
  end
end
