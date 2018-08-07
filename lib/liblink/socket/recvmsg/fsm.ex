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

defmodule Liblink.Socket.Recvmsg.Fsm do
  alias Liblink.Socket.Device
  alias Liblink.Socket.Recvmsg.InitState

  @opaque data_t :: map()

  @type next_state :: {module, data_t}

  @type fsm_return ::
          {:cont, term, next_state}
          | {:cont, next_state}
          | {:halt, term, next_state}
          | {:halt, next_state}

  defmacro __using__([]) do
    quote do
      use Liblink.Logger

      @behaviour Liblink.Socket.Recvmsg.Fsm

      @impl true
      def halt(data) do
        {:halt, :ok, {Liblink.Socket.Recvmsg.TermState, data}}
      end

      @impl true
      def attach(_device, data) do
        {:cont, {:error, :badstate}, {__MODULE__, data}}
      end

      @impl true
      def recvmsg(data) do
        {:cont, {:error, :badstate}, {__MODULE__, data}}
      end

      @impl true
      def poll(_pid, data) do
        {:cont, {:error, :badstate}, {__MODULE__, data}}
      end

      @impl true
      def halt_poll(_tag, data) do
        {:cont, {:error, :badstate}, {__MODULE__, data}}
      end

      @impl true
      def consume(_consumer, data) do
        {:cont, {:error, :badstate}, {__MODULE__, data}}
      end

      @impl true
      def halt_consumer(data) do
        {:cont, {:error, :badstate}, {__MODULE__, data}}
      end

      @impl true
      def on_liblink_message(_message, data) do
        {:cont, {:error, :badstate}, {__MODULE__, data}}
      end

      @impl true
      def on_monitor_message(message, data) do
        Liblink.Logger.warn("ignoring monitor message message=#{inspect(message)}")

        {:cont, :ok, {__MODULE__, data}}
      end

      defoverridable Liblink.Socket.Recvmsg.Fsm
    end
  end

  @spec new() :: {InitState, data_t}
  def new() do
    {InitState, %{}}
  end

  @callback halt(data_t) :: fsm_return

  @callback attach(Device.t(), data_t) :: fsm_return

  @callback recvmsg(data_t) :: fsm_return

  @callback poll({pid | atom | {atom, atom}}, data_t) :: fsm_return

  @callback halt_poll(reference, data_t) :: fsm_return

  @callback consume(pid | {module, atom, [term]}, data_t) :: fsm_return

  @callback halt_consumer(data_t) :: fsm_return

  @callback on_liblink_message(iodata, data_t) :: fsm_return

  @callback on_monitor_message({:DOWN, reference, :process, pid | {atom, atom}, atom}, data_t) ::
              fsm_return
end
