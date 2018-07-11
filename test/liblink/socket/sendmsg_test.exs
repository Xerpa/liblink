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

defmodule Liblink.Socket.SendmsgTest do
  use ExUnit.Case, async: true

  alias Liblink.Nif
  alias Liblink.Socket.Device
  alias Liblink.Socket.Sendmsg

  import Liblink.Random

  @moduletag capture_log: true

  setup env do
    {:ok, pid} = Sendmsg.start()

    endpoint = random_inproc_endpoint()

    {:ok, router} =
      Nif.new_socket(
        :router,
        "@" <> endpoint,
        random_inproc_endpoint(),
        self()
      )

    :ok = Nif.signal(router, :cont)

    {:ok, dealer} =
      Nif.new_socket(
        :dealer,
        ">" <> endpoint,
        random_inproc_endpoint(),
        self()
      )

    :ok = Nif.signal(dealer, :cont)

    device = %Device{sendmsg_pid: pid, socket: router}

    unless env[:no_attach] do
      :ok = Sendmsg.attach(pid, device)
    end

    on_exit(fn ->
      Sendmsg.halt(pid)
      Nif.term(dealer)
      Nif.term(router)
    end)

    {:ok, [sendmsg: pid, device: device, dealer: dealer]}
  end

  describe "start" do
    test "creates a pid" do
      {:ok, pid} = Sendmsg.start()
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "halt" do
    @tag no_attach: true
    test "halting a detached process", %{sendmsg: pid} do
      assert :ok == Sendmsg.halt(pid)
      refute Process.alive?(pid)
    end

    test "halting an attached process", %{sendmsg: pid} do
      assert :ok == Sendmsg.halt(pid)
      refute Process.alive?(pid)
    end

    test "halting twice", %{sendmsg: pid} do
      assert :ok == Sendmsg.halt(pid)
      assert :ok == Sendmsg.halt(pid)
    end
  end

  describe "send_async" do
    test "sending one message", %{sendmsg: pid, dealer: dealer} do
      assert :ok == Nif.sendmsg(dealer, "ping")
      assert_receive {:liblink_message, ["ping", msgkey]}
      Sendmsg.sendmsg_async(pid, [msgkey, "pong"], :infinity)
      assert_receive {:liblink_message, ["pong"]}
    end

    test "sending multiple messages", %{sendmsg: pid, dealer: dealer} do
      assert :ok == Nif.sendmsg(dealer, "ping")
      assert_receive {:liblink_message, ["ping", msgkey]}
      Sendmsg.sendmsg_async(pid, [msgkey, "pong-0"], :infinity)
      Sendmsg.sendmsg_async(pid, [msgkey, "pong-1"], :infinity)
      assert_receive {:liblink_message, ["pong-0"]}
      assert_receive {:liblink_message, ["pong-1"]}
    end
  end

  describe "send" do
    test "sending one message", %{sendmsg: pid, dealer: dealer} do
      assert :ok == Nif.sendmsg(dealer, "ping")
      assert_receive {:liblink_message, ["ping", msgkey]}
      assert :ok == Sendmsg.sendmsg(pid, [msgkey, "pong"], :infinity)
      assert_receive {:liblink_message, ["pong"]}
    end

    test "sending multiple messages", %{sendmsg: pid, dealer: dealer} do
      assert :ok == Nif.sendmsg(dealer, "ping")
      assert_receive {:liblink_message, ["ping", msgkey]}
      assert :ok == Sendmsg.sendmsg(pid, [msgkey, "pong-0"], :infinity)
      assert :ok == Sendmsg.sendmsg(pid, [msgkey, "pong-1"], :infinity)
      assert_receive {:liblink_message, ["pong-0"]}
      assert_receive {:liblink_message, ["pong-1"]}
    end

    test "timeout", %{sendmsg: pid} do
      assert {:error, :timeout} == Sendmsg.sendmsg(pid, "foobar", 0)
    end
  end
end
