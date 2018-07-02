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
        _ =
          Logger.warn(
            "removing misbehaving consumer [reason: exception]",
            metadata: [data: [consumer: data.consumer], except: e]
          )

        Transition.consume_to_recv(message, data)

      badmsg ->
        _ =
          Logger.warn(
            "removing misbehaving consumer [reason: badmsg]",
            metadata: [data: [consumer: data.consumer, badmsg: badmsg]]
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
        _ = Logger.warn("removing dead consumer", data: [tag: tag])
        Transition.consume_to_recv(data)

      _otherwise ->
        _ =
          Logger.debug(
            "discarding unknown monitor message",
            metadata: [data: [message: message, state: __MODULE__]]
          )

        {:cont, :ok, {__MODULE__, data}}
    end
  end

  defp invoke_fn({module, function, args}) do
    try do
      apply(module, function, args)
    rescue
      e ->
        _ =
          Logger.warn(
            "error invoking function",
            metadata: [data: [function: {module, function, args}], except: e]
          )

        {:error, e}
    end
  end

  defp invoke_fn(fun, message) when is_function(fun, 1) do
    try do
      apply(fun, [message])
    rescue
      e ->
        _ =
          Logger.warn(
            "error invoking function",
            metadata: [data: [function: fun], except: e]
          )

        {:error, e}
    end
  end

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
