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

defmodule Liblink.Socket.Recvmsg.ImplTest do
  use ExUnit.Case, async: true

  alias Liblink.Socket.Device
  alias Liblink.Socket.Recvmsg.Impl

  @moduletag capture_log: true

  setup env do
    device = %Device{}
    {:ok, state} = Impl.init()

    {:noreply, state} =
      unless env[:no_attach] do
        Impl.attach(device, :async, state)
      else
        {:noreply, state}
      end

    {:ok, [state: state]}
  end

  describe "in recv state" do
    test "empty queue", %{state: state} do
      assert {:reply, {:error, :empty}, _state} = Impl.recvmsg(:sync, state)
    end

    test "after receiving one message", %{state: state} do
      assert {:noreply, state} = Impl.on_liblink_message([:foobar], :async, state)
      assert {:reply, {:ok, [:foobar]}, _state} = Impl.recvmsg(:sync, state)
    end

    test "poll an empty queue", %{state: state} do
      assert {:reply, {:ok, _tag}, _} = Impl.poll(:infinity, self(), :sync, state)
      refute_receive _
    end

    test "poll after receiving one message", %{state: state} do
      assert {:noreply, state} = Impl.on_liblink_message([:foobar], :async, state)
      assert {:reply, {:ok, tag}, _state} = Impl.poll(:infinity, self(), :sync, state)
      assert_receive {^tag, :data}
    end

    test "schedule poll notification", %{state: state} do
      assert {:reply, {:ok, tag}, _} = Impl.poll(0, self(), :sync, state)
      assert_receive {:halt, :poll, ^tag}
    end

    test "notify poll about timeout", %{state: state} do
      {:reply, {:ok, tag}, state} = Impl.poll(0, self(), :sync, state)
      assert {:noreply, _} = Impl.halt_poll(tag, :async, state)
      assert_receive {^tag, :timeout}
    end
  end

  describe "in subs state" do
    setup env do
      {:noreply, state} = Impl.consume(self(), :async, env.state)
      {:ok, [state: state]}
    end

    test "proxy one message to consumer", %{state: state} do
      {:noreply, _} = Impl.on_liblink_message([:foobar], :async, state)
      assert_receive {Liblink.Socket, :data, [:foobar]}
    end

    test "proxy all messages to consumer", %{state: state} do
      {:noreply, state} = Impl.on_liblink_message([:foo], :async, state)
      {:noreply, _} = Impl.on_liblink_message([:bar], :async, state)
      assert_receive {Liblink.Socket, :data, [:foo]}
      assert_receive {Liblink.Socket, :data, [:bar]}
    end

    test "halt consumer when after it dies", %{state: state} do
      {_, data} = state.fsm
      tag = data.consumer.tag

      {:noreply, state} =
        Impl.on_monitor_message({:DOWN, tag, :process, self(), :normal}, :async, state)

      {:noreply, _} = Impl.on_liblink_message([:bar], :async, state)
      refute_receive _
    end
  end
end
