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

defmodule Liblink.Socket.RecvmsgTest do
  use ExUnit.Case, async: true

  alias Liblink.Socket.Device
  alias Liblink.Socket.Recvmsg

  @moduletag capture_log: true

  setup do
    {:ok, pid} = Recvmsg.start()

    device = %Device{}
    :ok = Recvmsg.attach(pid, device)

    {:ok, [pid: pid]}
  end

  describe "recvmsg/poll" do
    test "recvmsg when queue is empty", %{pid: pid} do
      assert {:error, :empty} == Recvmsg.recvmsg(pid, :infinity)
    end

    test "recvmsg after receiving message", %{pid: pid} do
      send(pid, {:liblink_message, ["foobar"]})
      assert {:ok, ["foobar"]} = Recvmsg.recvmsg(pid, :infinity)
    end

    test "recvmsg consumes message from the queue", %{pid: pid} do
      send(pid, {:liblink_message, ["foobar"]})
      assert {:ok, _} = Recvmsg.recvmsg(pid, :infinity)
      assert {:error, :empty} = Recvmsg.recvmsg(pid, :infinity)
    end

    test "poll notifies when a message arrives", %{pid: pid} do
      assert {:ok, tag} = Recvmsg.poll(pid, :infinity)
      send(pid, {:liblink_message, ["foobar"]})
      assert_receive {^tag, :data}
    end

    test "poll notifies when timeout expires", %{pid: pid} do
      assert {:ok, tag} = Recvmsg.poll(pid, 100)
      assert_receive {^tag, :timeout}, :infinity
    end
  end

  describe "consume" do
    test "consume proxy all messages", %{pid: pid} do
      assert :ok = Recvmsg.consume(pid, self(), :infinity)
      send(pid, {:liblink_message, ["foobar"]})
      assert_receive {Liblink.Socket, :data, ["foobar"]}
    end

    test "cancel subscription if proc dies", %{pid: pid} do
      {consumer, ref} = spawn_monitor(fn -> :timer.sleep(100) end)
      assert :ok == Recvmsg.consume(pid, consumer, :infinity)
      assert_receive {:DOWN, ^ref, :process, _, _}, :infinity
      # XXX: recv only works if the recvmsg halts the consumer
      assert {:error, :empty} == Recvmsg.recvmsg(pid, :infinity)
    end
  end
end
