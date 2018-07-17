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

defmodule Liblink.Cluster.Protocol.Dealer.DealerTest do
  use ExUnit.Case, async: true

  alias Liblink.Socket
  alias Liblink.Data.Message
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Cluster.Protocol.Dealer
  alias Liblink.Cluster.Protocol.Router
  alias Test.Liblink.TestService

  @moduletag capture_log: true

  describe "start_link" do
    test "default options" do
      assert {:ok, pid} = Dealer.start_link([])
      assert is_pid(pid)
    end

    test "init_hook is called" do
      self = self()
      assert {:ok, _pid} = Dealer.start_link(init_hook: fn -> send(self, :init_hook) end)
      assert_receive :init_hook
    end
  end

  describe "halt" do
    test "terminates the server" do
      {:ok, pid} = Dealer.start_link()
      tag = Process.monitor(pid)
      Dealer.halt(pid)
      assert_receive {:DOWN, ^tag, :process, ^pid, :normal}
    end
  end

  describe "device management" do
    setup do
      endpoint = "inproc://#{__MODULE__}"
      {:ok, device} = Socket.open(:dealer, ">" <> endpoint)

      on_exit(fn ->
        Socket.close(device)
      end)

      {:ok, dealer} = Dealer.start_link()

      {:ok,
       [
         dealer: dealer,
         device: device
       ]}
    end

    test "can attach a device", %{dealer: dealer, device: device} do
      assert :ok == Dealer.attach(dealer, device)
      assert MapSet.new([device]) == Dealer.devices(dealer)
    end

    test "can detach a device", %{dealer: dealer, device: device} do
      assert :ok == Dealer.attach(dealer, device)
      assert :ok == Dealer.detach(dealer, device)
      assert MapSet.new() == Dealer.devices(dealer)
    end

    test "can reattach a device", %{dealer: dealer, device: device} do
      assert :ok == Dealer.attach(dealer, device)
      assert :ok == Dealer.detach(dealer, device)
      assert :ok == Dealer.attach(dealer, device)
      assert MapSet.new([device]) == Dealer.devices(dealer)
    end

    test "can detach a non-attached device", %{dealer: dealer, device: device} do
      assert :ok == Dealer.detach(dealer, device)
    end

    test "can attach twice", %{dealer: dealer, device: device} do
      assert :ok == Dealer.attach(dealer, device)
      assert :ok == Dealer.attach(dealer, device)
      assert MapSet.new([device]) == Dealer.devices(dealer)
    end
  end

  describe "request" do
    setup env do
      endpoint = "inproc://#{__MODULE__}"
      {:ok, router} = Socket.open(:router, "@" <> endpoint)
      {:ok, dealer} = Socket.open(:dealer, ">" <> endpoint)

      on_exit(fn ->
        Socket.close(dealer)
        Socket.close(router)
      end)

      service =
        Service.new!(
          id: "liblink",
          exports: Exports.new!(:module, module: TestService),
          protocol: :request_response
        )

      state = Router.new!("liblink", [service])
      :ok = Socket.consume(router, {Router, :handler, [router, state]})

      {:ok, pid} = Dealer.start_link()

      unless env[:no_attach] do
        :ok = Dealer.attach(pid, dealer)
      end

      {:ok,
       [
         dealer: pid,
         device: dealer,
         ping_service: %{"ll-service-id" => {"liblink", :ping}},
         echo_service: %{"ll-service-id" => {"liblink", :echo}}
       ]}
    end

    @tag no_attach: true
    test "without devices", %{dealer: dealer} do
      assert {:error, :no_connection} == Dealer.request(dealer, Message.new(:payload))
    end

    @tag no_attach: true
    test "after adding device", %{dealer: dealer, device: device, ping_service: headers} do
      assert :ok == Dealer.attach(dealer, device)
      assert {:ok, _message} = Dealer.request(dealer, Message.new(:ping, headers))
    end

    test "after removing device", %{dealer: dealer, device: device} do
      assert :ok == Dealer.detach(dealer, device)

      assert {:error, :no_connection} == Dealer.request(dealer, Message.new(:payload))
    end

    test "requests a service", %{dealer: dealer, ping_service: headers} do
      assert {:ok, message} = Dealer.request(dealer, Message.new(:ping, headers))
      assert {:ok, :success} == Message.meta_fetch(message, "ll-status")
      assert :pong == message.payload
    end

    test "request a missing service", %{dealer: dealer} do
      assert {:ok, message} = Dealer.request(dealer, Message.new(nil))
      assert {:ok, :failure} == Message.meta_fetch(message, "ll-status")
      assert {:error, :not_found} == message.payload
    end

    test "can user dealer concurrently", %{dealer: dealer, echo_service: headers} do
      replies =
        0..100
        |> Enum.map(fn id ->
          Task.async(fn ->
            request = Message.new({:echo, {:ok, Message.new(id)}}, headers)
            {id, Dealer.request(dealer, request)}
          end)
        end)
        |> Enum.map(&Task.await/1)

      for {id, reply} <- replies do
        assert {:ok, reply = %Message{}} = reply
        assert {:ok, :success} = Message.meta_fetch(reply, "ll-status")
        assert id == reply.payload
      end
    end
  end
end
