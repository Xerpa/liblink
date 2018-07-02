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

defmodule Liblink.Socket do
  alias Liblink.Nif
  alias Liblink.Socket.Monitor
  alias Liblink.Socket.Sendmsg
  alias Liblink.Socket.Recvmsg

  @dialyzer [:unknown]

  def open(type, endpoint) do
    uniqid = to_string(:erlang.unique_integer())
    int_endpoint = "inproc://liblink-socket-device-" <> uniqid

    Monitor.new_device(fn recvmsg -> Nif.new_socket(type, endpoint, int_endpoint, recvmsg) end)
  end

  def close(device) do
    Recvmsg.halt(device.recvmsg_pid)
    Sendmsg.halt(device.sendmsg_pid)

    :ok
  end

  def sendmsg(device, message, timeout \\ 1_000) do
    Sendmsg.sendmsg(device.sendmsg_pid, message, timeout)
  end

  def sendmsg_async(device, message, timeout \\ :infinity) do
    Sendmsg.sendmsg_async(device.sendmsg_pid, message, timeout)
  end

  def recvmsg(device, timeout \\ 1_000) do
    case Recvmsg.recvmsg(device.recvmsg_pid, timeout) do
      {:error, :empty} ->
        case Recvmsg.poll(device.recvmsg_pid, timeout) do
          {:ok, tag} ->
            receive do
              {^tag, :data} ->
                Recvmsg.recvmsg(device.recvmsg_pid, timeout)

              {^tag, :timeout} ->
                {:error, :timeout}
            end
        end

      reply ->
        reply
    end
  end

  def consume(device, consumer, timeout \\ 1_000) do
    Recvmsg.consume(device.recvmsg_pid, consumer, timeout)
  end
end
