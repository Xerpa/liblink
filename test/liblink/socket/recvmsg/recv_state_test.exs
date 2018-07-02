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

defmodule Liblink.Socket.Recvmsg.RecvStateTest do
  use ExUnit.Case, async: true

  alias Liblink.Socket.Device
  alias Liblink.Socket.Recvmsg.Fsm
  alias Liblink.Socket.Recvmsg.InitState
  alias Liblink.Socket.Recvmsg.RecvState
  alias Liblink.Socket.Recvmsg.SubsState
  alias Liblink.Socket.Recvmsg.TermState

  @moduletag capture_log: true

  setup do
    device = %Device{}
    {InitState, data} = Fsm.new()
    {:cont, :ok, {RecvState, data}} = InitState.attach(device, data)

    {:ok, [data: data, device: device]}
  end

  test "can't attach", %{data: data} do
    assert {:cont, {:error, :badstate}, {RecvState, _}} = RecvState.attach(%Device{}, data)
  end

  test "at first there is no messages", %{data: data} do
    assert {:cont, {:error, :empty}, {RecvState, _}} = RecvState.recvmsg(data)
  end

  test "can halt", %{data: data} do
    assert {:halt, :ok, {TermState, _}} = RecvState.halt(data)
  end

  test "recvmsg when queue is empty", %{data: data} do
    assert {:cont, {:error, :empty}, {RecvState, _}} = RecvState.recvmsg(data)
  end

  test "recvmsg when queue is not empty", %{data: data} do
    data = Map.update!(data, :mqueue, &:queue.in([:message], &1))
    assert {:cont, {:ok, [:message]}, {RecvState, n_data}} = RecvState.recvmsg(data)
    assert {:cont, {:error, :empty}, {RecvState, _}} = RecvState.recvmsg(n_data)
  end

  test "recvmsg reverses message", %{data: data} do
    assert {:cont, :ok, {RecvState, n_data}} = RecvState.on_liblink_message([:bar, :foo], data)
    assert {:cont, {:ok, [:foo, :bar]}, {RecvState, _}} = RecvState.recvmsg(n_data)
  end

  test "poll notify right away if there is pending messages", %{data: data} do
    assert {:cont, :ok, {RecvState, n_data}} = RecvState.on_liblink_message([:foobar], data)
    assert {:cont, {:ok, tag}, {RecvState, _}} = RecvState.poll(self(), n_data)
    assert_receive {^tag, :data}
  end

  test "poll don't notify on_liblink_message if there is pending messages", %{data: data} do
    assert {:cont, :ok, {RecvState, n_data}} = RecvState.on_liblink_message([:foobar], data)
    assert {:cont, {:ok, tag}, {RecvState, n_data}} = RecvState.poll(self(), n_data)
    assert {:cont, :ok, {RecvState, _}} = RecvState.on_liblink_message([:foobar], n_data)

    assert_receive {^tag, :data}
    refute_receive _
  end

  test "poll notify on on_libliblink_message", %{data: data} do
    assert {:cont, {:ok, tag}, {RecvState, n0_data}} = RecvState.poll(self(), data)
    refute_receive _

    assert {:cont, :ok, {RecvState, _}} = RecvState.on_liblink_message([:message], n0_data)
    assert_receive {^tag, :data}
  end

  test "poll notify multiple pollers", %{data: data} do
    assert {:cont, {:ok, tag0}, {RecvState, n_data}} = RecvState.poll(self(), data)
    assert {:cont, {:ok, tag1}, {RecvState, n_data}} = RecvState.poll(self(), n_data)

    assert {:cont, :ok, {RecvState, _}} = RecvState.on_liblink_message([:message], n_data)
    assert_receive {^tag0, :data}
    assert_receive {^tag1, :data}
  end

  test "poll is canceled after notification", %{data: data} do
    assert {:cont, {:ok, tag}, {RecvState, n_data}} = RecvState.poll(self(), data)
    assert {:cont, :ok, {RecvState, n_data}} = RecvState.on_liblink_message([:message], n_data)
    assert {:cont, :ok, {RecvState, _}} = RecvState.on_liblink_message([:message], n_data)

    assert_receive {^tag, :data}
    refute_receive _
  end

  test "halt_poll notify timeout", %{data: data} do
    assert {:cont, {:ok, tag}, {RecvState, n_data}} = RecvState.poll(self(), data)
    assert {:cont, :ok, {RecvState, _}} = RecvState.halt_poll(tag, n_data)

    assert_receive {^tag, :timeout}
  end

  test "poll is canceled after halt_poll", %{data: data} do
    assert {:cont, {:ok, tag}, {RecvState, n_data}} = RecvState.poll(self(), data)
    assert {:cont, :ok, {RecvState, n_data}} = RecvState.halt_poll(tag, n_data)
    assert {:cont, :ok, {RecvState, _}} = RecvState.halt_poll(tag, n_data)

    assert_receive {^tag, :timeout}
    refute_receive _
  end

  test "on_liblink_message save message", %{data: data} do
    assert {:cont, :ok, {RecvState, n_data}} = RecvState.on_liblink_message([:message], data)
    assert {:cont, {:ok, [:message]}, _} = RecvState.recvmsg(n_data)
  end

  test "on_liblink_message keeps message in fifo order", %{data: data} do
    assert {:cont, :ok, {RecvState, n_data}} = RecvState.on_liblink_message([:foo], data)
    assert {:cont, :ok, {RecvState, n_data}} = RecvState.on_liblink_message([:bar], n_data)
    assert {:cont, {:ok, [:foo]}, {RecvState, n_data}} = RecvState.recvmsg(n_data)
    assert {:cont, {:ok, [:bar]}, _} = RecvState.recvmsg(n_data)
  end

  test "consume moves to subs state", %{data: data} do
    assert {:cont, :ok, {SubsState, _}} = RecvState.consume(self(), data)
    refute_receive _
  end

  test "consume flushes all pending messages", %{data: data} do
    assert {:cont, :ok, {RecvState, n_data}} = RecvState.on_liblink_message([:foo], data)
    assert {:cont, :ok, {SubsState, _}} = RecvState.consume(self(), n_data)

    assert_receive {Liblink.Socket, :data, [:foo]}
  end

  test "consume halt all poll requests", %{data: data} do
    assert {:cont, {:ok, tag}, {RecvState, n_data}} = RecvState.poll(self(), data)
    assert {:cont, :ok, {SubsState, _}} = RecvState.consume(self(), n_data)

    assert_receive {^tag, :timeout}
  end
end
