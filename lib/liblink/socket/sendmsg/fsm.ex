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

defmodule Liblink.Socket.Sendmsg.Fsm do
  alias Liblink.Socket.Device
  alias Liblink.Socket.Sendmsg.InitState

  @opaque data_t :: map()

  @type next_state :: {module, data_t}

  @type fsm_return ::
          {:cont, term, next_state}
          | {:halt, term, next_state}
          | {:cont, next_state}
          | {:halt, next_state}

  defmacro __using__([]) do
    quote do
      @behaviour Liblink.Socket.Sendmsg.Fsm

      @impl true
      def halt(data) do
        {:halt, :ok, {Liblink.Socket.Sendmsg.TermState, data}}
      end

      @impl true
      def attach(_device, data) do
        {:cont, {:error, :badstate}, {__MODULE__, data}}
      end

      @impl true
      def sendmsg(_iodata, _deadline, data) do
        {:cont, {:error, :badstate}, {__MODULE__, data}}
      end

      defoverridable Liblink.Socket.Sendmsg.Fsm
    end
  end

  @spec new() :: {InitState, data_t}
  def new() do
    {InitState, %{}}
  end

  @callback halt(data_t) :: fsm_return

  @callback attach(Device.t(), data_t) :: fsm_return

  @callback sendmsg(iodata, Timeout.deadline_t(), data_t) :: fsm_return
end
