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

defmodule Liblink.Socket.Recvmsg.SubsState do
  use Liblink.Socket.Recvmsg.Fsm

  alias Liblink.Socket.Recvmsg.Transition

  @type consumer_t :: {atom, atom, list} | (iodata -> term) | pid | atom | {atom, atom}

  @impl true
  def halt_consumer(data) do
    Transition.consume_to_recv(data)
  end

  @impl true
  def on_liblink_message(message, data) do
    case invoke_consumer(data.consumer, message) do
      :ok ->
        {:cont, :ok, {__MODULE__, data}}

      {:error, e} ->
        Liblink.Logger.warn(
          "removing misbehaving consumer message=#{inspect(message)} reason=#{inspect(e)}"
        )

        Transition.consume_to_recv(message, data)

      badmsg ->
        Liblink.Logger.warn(
          "removing misbehaving consumer message=#{inspect(badmsg)} reason=:badmsg"
        )

        Transition.consume_to_recv(message, data)
    end
  end

  @impl true
  def on_monitor_message(message, data) do
    tag = data.consumer.tag
    Process.demonitor(tag)

    case message do
      {:DOWN, ^tag, :process, _object, _reason} ->
        Liblink.Logger.warn("removing dead consumer")
        Transition.consume_to_recv(data)

      _otherwise ->
        Liblink.Logger.debug("discarding unknown monitor message message=#{inspect(message)}")

        {:cont, :ok, {__MODULE__, data}}
    end
  end

  @spec invoke_fn({atom, atom, list}) :: term | {:error, term}
  defp invoke_fn({module, function, args}) do
    try do
      apply(module, function, args)
    rescue
      e ->
        Liblink.Logger.warn(
          "error invoking function module=#{module} function=#{function} args=#{inspect(args)} except=#{
            inspect(e)
          }"
        )

        {:error, e}
    end
  end

  @spec invoke_fn((iodata -> term), iodata) :: term | {:error, term}
  defp invoke_fn(fun, message) when is_function(fun, 1) do
    try do
      apply(fun, [message])
    rescue
      e ->
        Liblink.Logger.warn("error invoking function except=#{inspect(e)}")

        {:error, e}
    end
  end

  @spec invoke_consumer(%{pid_or_fun: consumer_t}, iodata) :: term
  defp invoke_consumer(consumer, message) do
    message = Enum.reverse(message)

    if Map.has_key?(consumer, :tag) do
      invoke_fn({Process, :send, [consumer.pid_or_fun, {Liblink.Socket, :data, message}, []]})
    else
      case consumer.pid_or_fun do
        {module, function, args} ->
          invoke_fn({module, function, [message | args]})

        anon_fn ->
          invoke_fn(anon_fn, message)
      end
    end
  end
end
