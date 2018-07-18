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

defmodule Liblink.Cluster.Protocol.Dealer.ImplTest do
  use ExUnit.Case, async: true

  alias Liblink.Timeout
  alias Liblink.Socket
  alias Liblink.Cluster.Protocol.Dealer.Impl

  @moduletag capture_log: true

  describe "new" do
    test "default options" do
      assert {:ok, state} = Impl.new([])
      assert is_function(state.balance)
      assert Enum.empty?(state.devices)
    end

    test "validation" do
      assert {:error, {:balance, :bad_value}} == Impl.new(balance: :foobar)
    end
  end

  describe "add_device" do
    setup do
      {:ok, device} = Socket.open(:dealer, "@inproc://#{__MODULE__}")

      on_exit(fn ->
        Socket.close(device)
      end)

      {:ok, state} = Impl.new([])

      {:ok, [state: state, device: device]}
    end

    test "add one device", %{state: state, device: device} do
      assert {:reply, :ok, state} = Impl.add_device(device, state)
      assert [device] == Enum.to_list(state.devices)
    end

    test "add the same device twice", %{state: state, device: device} do
      assert {:reply, :ok, state} = Impl.add_device(device, state)
      assert {:reply, :ok, state} = Impl.add_device(device, state)
      assert [device] == Enum.to_list(state.devices)
    end
  end

  describe "del_device" do
    setup do
      {:ok, device} = Socket.open(:dealer, "@inproc://#{__MODULE__}")

      on_exit(fn ->
        Socket.close(device)
      end)

      {:ok, state} = Impl.new(devices: [device])

      {:ok, [state: state, device: device]}
    end

    test "can remove device", %{state: state, device: device} do
      assert {:reply, :ok, state} = Impl.del_device(device, state)
      assert Enum.empty?(state.devices)
    end

    test "remove the same device twice", %{state: state, device: device} do
      assert {:reply, :ok, state} = Impl.del_device(device, state)
      assert {:reply, :ok, state} = Impl.del_device(device, state)
      assert Enum.empty?(state.devices)
    end
  end

  describe "timeout_step" do
    setup env do
      {:ok, state} = Impl.new([])

      tag = ""
      req = :anything

      state =
        if env[:with_timeout] do
          requests = %{tag => req}
          timeouts = %{tag => env.with_timeout}
          %{state | timeouts: timeouts, requests: requests}
        else
          state
        end

      {:ok, [state: state, tag: tag, request: req]}
    end

    test "setup configuration", %{state: state} do
      assert %{} == state.requests
      assert %{} == state.timeouts
    end

    @tag with_timeout: 1
    test "setup configuration | with_timeout", %{state: state, tag: tag, request: request} do
      assert %{tag => request} == state.requests
      assert %{tag => 1} == state.timeouts
    end

    test "do nothing on empty state", %{state: state} do
      assert {:noreply, state} == Impl.timeout_step(state)
    end

    @tag with_timeout: 1
    test "delete expired requests", %{state: state} do
      assert {:noreply, state} = Impl.timeout_step(state)
      assert %{} == state.timeouts
      assert %{} == state.requests
    end

    @tag with_timeout: 2
    test "keep pending requests", %{state: state, tag: tag, request: request} do
      assert {:noreply, state} = Impl.timeout_step(state)
      assert %{tag => 1} == state.timeouts
      assert %{tag => request} == state.requests
    end

    @tag with_timeout: 2
    test "eventually expire requests", %{state: state} do
      assert {:noreply, state} = Impl.timeout_step(state)
      assert {:noreply, state} = Impl.timeout_step(state)
      assert %{} == state.timeouts
      assert %{} == state.requests
    end
  end

  describe "route_message" do
    setup env do
      deadline =
        case Map.fetch(env, :with_deadline) do
          :error -> :infinity
          {:ok, timeout} -> Timeout.deadline(timeout, :millisecond)
        end

      tag = ""
      req = {self(), deadline}

      {:ok, state} = Impl.new([])
      state = %{state | requests: %{tag => req}, timeouts: %{tag => 1}}

      {:ok, [state: state, tag: tag]}
    end

    test "setup configuration", %{state: state, tag: tag} do
      assert %{tag => {self(), :infinity}} == state.requests
      assert %{tag => 1} == state.timeouts
    end

    test "route message to caller", %{state: state, tag: tag} do
      message = [tag, :payload]
      assert {:noreply, state} = Impl.route_message(message, state)
      assert %{} == state.requests
      assert %{} == state.timeouts
      assert_receive {^tag, [:payload]}
    end

    test "ignore unknown tags", %{state: state, tag: tag} do
      message = [tag <> "x", :payload]
      assert {:noreply, state} == Impl.route_message(message, state)
      assert %{^tag => _} = state.requests
      assert %{^tag => _} = state.timeouts
    end

    @tag with_deadline: -1
    test "ignore expired messages", %{state: state, tag: tag} do
      message = [tag, :payload]
      assert {:noreply, state} = Impl.route_message(message, state)
      refute_receive _
      assert %{} == state.requests
      assert %{} == state.timeouts
    end
  end

  describe "sendmsg" do
    setup do
      endpoint = "inproc://#{__MODULE__}"
      {:ok, router} = Socket.open(:router, "@" <> endpoint)
      {:ok, dealer} = Socket.open(:dealer, ">" <> endpoint)

      :ok = Socket.consume(router, self())

      on_exit(fn ->
        Socket.close(dealer)
        Socket.close(router)
      end)

      {:ok, state} = Impl.new([])
      {:reply, :ok, state} = Impl.add_device(dealer, state)

      {:ok, [router: router, state: state]}
    end

    test "sendmsg register the request and timeout", %{state: state} do
      assert {:reply, {:ok, tag}, state} =
               Impl.sendmsg("payload", self(), [timeout_in_ms: 1_000], state)

      assert %{^tag => _request} = state.requests
      assert %{^tag => _timeout} = state.timeouts
    end

    test "sendmsg include tag in the message", %{state: state} do
      assert {:reply, {:ok, tag}, _state} =
               Impl.sendmsg("payload", self(), [timeout_in_ms: 1_000], state)

      assert_receive {Liblink.Socket, :data, [_, ^tag, "payload"]}
    end

    test "sendmsg uses restrict_fn to select devices", %{state: state} do
      assert {:reply, {:error, :no_connection}, _state} =
               Impl.sendmsg("payload", self(), [restrict_fn: fn _ -> MapSet.new() end], state)
    end
  end
end
