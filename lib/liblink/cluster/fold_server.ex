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

defmodule Liblink.Cluster.FoldServer do
  use GenServer

  @typep state_t :: %{
           :proc => proc,
           :interval => non_neg_integer,
           optional(:halted) => true
         }

  @type data :: term

  @type proc :: %{
          required(:exec) => (data -> data),
          required(:halt) => (data -> term),
          required(:data) => data
        }

  @type init_callback :: (() -> term)

  @spec start_link(proc, init_callback, non_neg_integer) :: {:ok, pid}
  def start_link(proc = %{exec: exec, halt: halt, data: _}, init_callback, interval_in_ms)
      when is_function(exec, 1) and is_function(halt, 1) and is_function(init_callback, 0) and
             is_integer(interval_in_ms) and interval_in_ms > 0 do
    state = %{proc: proc, interval: interval_in_ms}
    GenServer.start_link(__MODULE__, state: state, init_callback: init_callback)
  end

  @spec halt(pid) :: :ok
  def halt(pid) do
    GenServer.cast(pid, :halt)
  end

  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)

    state = Keyword.fetch!(args, :state)
    init_callback = Keyword.fetch!(args, :init_callback)
    apply(init_callback, [])

    state =
      state
      |> run_exec()
      |> schedule()

    {:ok, state}
  end

  @impl true
  def terminate(reason, state) do
    _ = run_halt(state)

    :ok
  end

  @impl true
  def handle_cast(message, state) do
    case message do
      :halt ->
        state = run_halt(state)

        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info(message, state) do
    self = self()

    case message do
      :exec ->
        state =
          state
          |> run_exec()
          |> schedule()

        {:noreply, state}

      {:EXIT, ^self, :normal} ->
        state = run_halt(state)

        {:stop, :normal, state}

      {:EXIT, _from, :normal} ->
        {:noreply, state}

      {:EXIT, _from, reason} ->
        state = run_halt(state)

        {:stop, reason, state}
    end
  end

  @spec schedule(state_t) :: state_t
  defp schedule(state) do
    Process.send_after(self(), :exec, state.interval)

    state
  end

  @spec run_exec(state_t) :: state_t
  defp run_exec(state) do
    proc = state.proc
    data = proc.exec.(proc.data)

    %{state | proc: %{proc | data: data}}
  end

  @spec run_halt(state_t) :: state_t
  defp run_halt(state = %{halted: true}), do: state

  defp run_halt(state) do
    state.proc.halt.(state.proc.data)

    Map.put(state, :halted, true)
  end
end
