# Copyright (C) 2018  Xerpa

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Liblink.Cluster.Protocol.Dealer.Impl do
  alias Liblink.Timeout
  alias Liblink.Socket
  alias Liblink.Socket.Device
  alias Liblink.Data.Keyword
  alias Liblink.Data.Balance

  import Liblink.Guards

  require Logger

  @type state_t :: %{
          devices: MapSet.t(Device.t()),
          balance: Balance.t(),
          requests: map,
          timeouts: map
        }

  @type sendmsg_opt ::
          {:timeout_in_ms, timeout}
          | {:restrict_fn, (MapSet.t(Device.t()) -> MapSet.t(Device.t()))}

  @type option :: {:balance, :round_robin}

  @spec new([option]) ::
          {:ok, state_t} | {:error, {:devices | :balance, :bad_value}} | Keyword.fetch_error()
  def new(options) when is_list(options) do
    with {:ok, algorithm} <- Keyword.fetch_atom(options, :balance, :round_robin),
         {_, true} <- {:balance, algorithm == :round_robin} do
      {:ok,
       %{
         devices: MapSet.new(),
         balance: &Balance.round_robin/1,
         requests: %{},
         timeouts: %{}
       }}
    else
      {key, false} ->
        {:error, {key, :bad_value}}

      error = {:error, _} ->
        error
    end
  end

  @spec add_device(Device.t(), state_t) :: {:reply, :ok | :error, state_t}
  def add_device(device = %Device{}, state) do
    if MapSet.member?(state.devices, device) do
      {:reply, :ok, state}
    else
      case Socket.consume(device, self()) do
        :ok ->
          state = Map.update!(state, :devices, &MapSet.put(&1, device))
          {:reply, :ok, state}

        _error ->
          {:reply, :error, state}
      end
    end
  end

  @spec devices(state_t) :: {:reply, [Device.t()], state_t}
  def devices(state) do
    {:reply, state.devices, state}
  end

  @spec halt(state_t) :: {:stop, :normal, state_t}
  def halt(state) do
    {:stop, :normal, %{state | devices: MapSet.new()}}
  end

  @spec del_device(Device.t(), state_t) :: {:reply, :ok, state_t}
  def del_device(device = %Device{}, state) do
    if MapSet.member?(state.devices, device) do
      _ = Socket.halt_consumer(device)
    end

    state = Map.update!(state, :devices, &MapSet.delete(&1, device))

    {:reply, :ok, state}
  end

  @spec sendmsg(iodata, pid, [sendmsg_opt], state_t) ::
          {:reply, {:ok, binary} | {:error, :no_connection}, state_t}
  def sendmsg(message, from, opts, state)
      when is_iodata(message) and is_pid(from) and is_list(opts) do
    tag = new_tag(state)

    payload = [tag | List.wrap(message)]

    timeout =
      case Keyword.fetch(opts, :timeout_in_ms) do
        {:ok, timeout} when is_integer(timeout) ->
          timeout

        {:ok, :infinity} ->
          :infinity

        _error ->
          1_000
      end

    restrict_fn =
      case Keyword.fetch_function(opts, :restrict_fn) do
        {:ok, restrict_fn} when is_function(restrict_fn, 1) -> restrict_fn
        _error -> fn x -> x end
      end

    deadline =
      if timeout == :infinity do
        :infinity
      else
        Timeout.deadline(timeout, :millisecond)
      end

    request_entry = {from, deadline}

    case state.balance.(restrict_fn.(state.devices)) do
      :error ->
        {:reply, {:error, :no_connection}, state}

      {:ok, device} ->
        state =
          if timeout == :infinity do
            Map.update!(state, :requests, &Map.put_new(&1, tag, request_entry))
          else
            state
            |> Map.update!(:timeouts, &Map.put_new(&1, tag, deadline))
            |> Map.update!(:requests, &Map.put_new(&1, tag, request_entry))
          end

        :ok = Socket.sendmsg_async(device, payload)

        {:reply, {:ok, tag}, state}
    end
  end

  @spec route_message(iodata, state_t) :: {:noreply, state_t}
  def route_message([tag | message], state) do
    case Map.pop(state.requests, tag) do
      {{from, deadline}, requests} ->
        unless Timeout.deadline_expired?(deadline) do
          send(from, {tag, message})
        end

        timeouts = Map.delete(state.timeouts, tag)

        {:noreply, %{state | requests: requests, timeouts: timeouts}}

      {nil, _requests} ->
        _ = Logger.debug("ignoring expired reply")
        {:noreply, state}
    end
  end

  @spec timeout_step(state_t) :: {:noreply, state_t}
  def timeout_step(state, sysnow \\ nil) do
    sysnow = sysnow || Timeout.current()

    {expired, timeouts} =
      Enum.reduce(state.timeouts, {[], %{}}, fn {tag, deadline}, {dead, alive} ->
        if Timeout.deadline_expired?(deadline, sysnow) do
          {[tag | dead], alive}
        else
          {dead, Map.put(alive, tag, deadline)}
        end
      end)

    state =
      state
      |> Map.put(:timeouts, timeouts)
      |> Map.update!(:requests, &Map.drop(&1, expired))

    {:noreply, state}
  end

  def timeout_interval, do: 1_000

  defp new_tag(state) do
    tag = :crypto.strong_rand_bytes(16)

    if Map.has_key?(state.requests, tag) do
      new_tag(state)
    else
      tag
    end
  end
end
