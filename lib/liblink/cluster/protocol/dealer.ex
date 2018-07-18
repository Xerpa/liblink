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

defmodule Liblink.Cluster.Protocol.Dealer do
  use GenServer

  alias Liblink.Socket
  alias Liblink.Socket.Device
  alias Liblink.Data.Message
  alias Liblink.Cluster.Protocol.Dealer.Impl
  alias Liblink.Data.Keyword

  import Liblink.Guards

  require Logger

  @type t :: pid

  @spec start_link([Impl.option() | {:init_hook, (() -> term)}]) :: {:ok, pid}
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options)
  end

  @spec devices(pid) :: [Device.t()]
  @spec devices(pid, timeout) :: [Device.t()]
  def devices(pid, timeout \\ 1_000) do
    GenServer.call(pid, :devices, timeout)
  end

  @spec attach(pid, Device.t(), timeout) :: :ok | no_return
  def attach(pid, device = %Device{}, timeout \\ 1_000)
      when is_pid(pid) and is_timeout(timeout) do
    GenServer.call(pid, {:add_dev, device}, timeout)
  end

  @spec detach(pid, Device.t(), timeout) :: :ok | no_return
  def detach(pid, device = %Device{}, timeout \\ 1_000)
      when is_pid(pid) and is_timeout(timeout) do
    GenServer.call(pid, {:del_dev, device}, timeout)
  end

  @spec halt(pid) :: :ok
  def halt(pid) do
    GenServer.cast(pid, :halt)
  end

  @spec request(t, Message.t(), [Impl.sendmsg_opt()]) ::
          {:ok, Message.t()} | {:error, :timeout} | {:error, :io_error} | {:error, :no_connection}
  def request(dealer, message = %Message{}, opts \\ [])
      when is_pid(dealer) and is_list(opts) do
    # FIXME: this might actually take ~ (2 * timeout_in_ms)
    timeout =
      case Keyword.fetch_integer(opts, :timeout_in_ms) do
        {:ok, timeout} -> timeout
        _error -> 1_000
      end

    payload = Message.encode(message)

    reply =
      try do
        GenServer.call(dealer, {:sendmsg, payload, self(), opts}, timeout)
      catch
        :exit, {:noproc, {GenServer, :call, _}} ->
          {:error, :io_error}

        :exit, {:timeout, {GenServer, :call, _}} ->
          {:error, :timeout}
      end

    with {:ok, tag} <- reply do
      receive do
        {^tag, reply} ->
          case Message.decode(reply) do
            :error -> {:error, :io_error}
            reply -> reply
          end
      after
        timeout -> {:error, :timeout}
      end
    end
  end

  @impl true
  def init(options) do
    {:ok, init_hook} = Keyword.fetch_function(options, :init_hook, fn -> nil end)
    init_hook.()
    Process.send_after(self(), :timeout_step, Impl.timeout_interval())
    Impl.new(options)
  end

  @impl true
  def handle_call(message, _from, state) do
    case message do
      {:sendmsg, message, from, timeout} ->
        Impl.sendmsg(message, from, timeout, state)

      {:add_dev, device} ->
        Impl.add_device(device, state)

      {:del_dev, device} ->
        Impl.del_device(device, state)

      :devices ->
        Impl.devices(state)

      message ->
        _ = Logger.debug("discarding unknown call message", metadata: [data: [message: message]])
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(message, state) do
    case message do
      :halt ->
        Impl.halt(state)

      _message ->
        _ = Logger.debug("discarding unknown cast message", metadata: [data: [message: message]])
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(message, state) do
    case message do
      :timeout_step ->
        Process.send_after(self(), :timeout_step, Impl.timeout_interval())
        Impl.timeout_step(state)

      {Socket, :data, message} ->
        Impl.route_message(message, state)
    end
  end
end
