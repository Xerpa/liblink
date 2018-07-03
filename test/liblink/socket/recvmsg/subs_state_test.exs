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

defmodule Liblink.Socket.Recvmsg.SubsStateTest do
  use ExUnit.Case, async: true

  alias Liblink.Socket.Device
  alias Liblink.Socket.Recvmsg.Fsm
  alias Liblink.Socket.Recvmsg.InitState
  alias Liblink.Socket.Recvmsg.RecvState
  alias Liblink.Socket.Recvmsg.SubsState
  alias Liblink.Socket.Recvmsg.TermState

  @moduletag capture_log: true

  def send_to_pid(message, pid) do
    Process.send(pid, message, [])
  end

  def return_error(_message) do
    :error
  end

  def raise_error(_message) do
    raise(RuntimeError)
  end

  setup env do
    this = self()

    consumer =
      case Map.fetch(env, :consumer_mode) do
        :error -> this
        {:ok, :process} -> this
        {:ok, :ok_anon_fun} -> fn message -> Process.send(this, message, []) end
        {:ok, :error_anon_fun} -> fn _message -> :error end
        {:ok, :faulty_anon_fun} -> fn _message -> raise(RuntimeError) end
        {:ok, :ok_function} -> {__MODULE__, :send_to_pid, [this]}
        {:ok, :error_function} -> {__MODULE__, :return_error, [this]}
        {:ok, :faulty_function} -> {__MODULE__, :raise_error, [this]}
        {:ok, :missing_function} -> {:missing_module, :missing_function, []}
      end

    device = %Device{}
    {InitState, data} = Fsm.new()
    {:cont, :ok, {RecvState, data}} = InitState.attach(device, data)
    {:cont, :ok, {SubsState, data}} = RecvState.consume(consumer, data)

    {:ok, [data: data, device: device]}
  end

  test "can halt", %{data: data} do
    assert {:halt, :ok, {TermState, _}} = SubsState.halt(data)
  end

  test "can't attach", %{data: data} do
    assert {:cont, {:error, :badstate}, {SubsState, _}} = SubsState.attach(%Device{}, data)
  end

  test "can't recvmsg", %{data: data} do
    assert {:cont, {:error, :badstate}, {SubsState, _}} = SubsState.recvmsg(data)
  end

  test "can't poll", %{data: data} do
    assert {:cont, {:error, :badstate}, {SubsState, _}} = SubsState.poll(self(), data)
  end

  test "can't halt_poll", %{data: data} do
    assert {:cont, {:error, :badstate}, {SubsState, _}} =
             SubsState.halt_poll(:erlang.make_ref(), data)
  end

  test "can't consume", %{data: data} do
    assert {:cont, {:error, :badstate}, {SubsState, _}} = SubsState.consume(self(), data)
  end

  test "proxy messages to process", %{data: data} do
    refute_receive _
    assert {:cont, :ok, {SubsState, _}} = SubsState.on_liblink_message([:foobar], data)
    assert_receive {Liblink.Socket, :data, [:foobar]}
  end

  test "proxy multiple messages to process", %{data: data} do
    assert {:cont, :ok, {SubsState, data}} = SubsState.on_liblink_message([:foo], data)
    assert {:cont, :ok, {SubsState, _}} = SubsState.on_liblink_message([:bar], data)
    assert_receive {Liblink.Socket, :data, [:foo]}
    assert_receive {Liblink.Socket, :data, [:bar]}
  end

  @tag consumer_mode: :ok_function
  test "proxy messages to remote function", %{data: data} do
    refute data.consumer[:tag]
    assert {:cont, :ok, {SubsState, _}} = SubsState.on_liblink_message([:foobar], data)

    assert_receive [:foobar]
  end

  @tag consumer_mode: :ok_function
  test "proxy multiple messages to remote function", %{data: data} do
    refute data.consumer[:tag]
    assert {:cont, :ok, {SubsState, data}} = SubsState.on_liblink_message([:foo], data)
    assert {:cont, :ok, {SubsState, _}} = SubsState.on_liblink_message([:bar], data)

    assert_receive [:foo]
    assert_receive [:bar]
  end

  @tag consumer_mode: :ok_anon_fun
  test "proxy messages to anonymous function", %{data: data} do
    refute data.consumer[:tag]
    assert {:cont, :ok, {SubsState, _}} = SubsState.on_liblink_message([:foobar], data)

    assert_receive [:foobar]
  end

  @tag consumer_mode: :ok_anon_fun
  test "proxy multiple messages to anonymous function", %{data: data} do
    refute data.consumer[:tag]
    assert {:cont, :ok, {SubsState, data}} = SubsState.on_liblink_message([:foo], data)
    assert {:cont, :ok, {SubsState, _}} = SubsState.on_liblink_message([:bar], data)

    assert_receive [:foo]
    assert_receive [:bar]
  end

  test "cancel subscription if consumer dies", %{data: data} do
    tag = data.consumer.tag

    assert {:cont, :ok, {RecvState, _}} =
             SubsState.on_monitor_message({:DOWN, tag, :process, self(), :normal}, data)
  end

  @tag consumer_mode: :error_function
  test "cancel subscription if function returns != :ok", %{data: data} do
    assert {:cont, :ok, {RecvState, data}} = SubsState.on_liblink_message([:foo], data)
    assert {:cont, {:ok, [:foo]}, _} = RecvState.recvmsg(data)
  end

  @tag consumer_mode: :error_anon_fun
  test "cancel subscription if anon function returns != :ok", %{data: data} do
    assert {:cont, :ok, {RecvState, data}} = SubsState.on_liblink_message([:foo], data)
    assert {:cont, {:ok, [:foo]}, _} = RecvState.recvmsg(data)
  end

  @tag consumer_mode: :faulty_function
  test "cancel subscription if function misbehaves", %{data: data} do
    assert {:cont, :ok, {RecvState, data}} = SubsState.on_liblink_message([:foo], data)
    assert {:cont, {:ok, [:foo]}, _} = RecvState.recvmsg(data)
  end

  @tag consumer_mode: :faulty_anon_fun
  test "cancel subscription if anon function misbehaves", %{data: data} do
    assert {:cont, :ok, {RecvState, data}} = SubsState.on_liblink_message([:foo], data)
    assert {:cont, {:ok, [:foo]}, _} = RecvState.recvmsg(data)
  end

  @tag consumer_mode: :missing_function
  test "cancel subscription if function does not exist", %{data: data} do
    assert {:cont, :ok, {RecvState, data}} = SubsState.on_liblink_message([:foo], data)
    assert {:cont, {:ok, [:foo]}, _} = RecvState.recvmsg(data)
  end

  test "reverses liblink messages", %{data: data} do
    assert {:cont, :ok, {SubsState, _}} = SubsState.on_liblink_message([:bar, :foo], data)
    assert_receive {Liblink.Socket, :data, [:foo, :bar]}
  end

  test "ignores dangling monitoring messages", %{data: data} do
    tag = :erlang.make_ref()

    assert {:cont, :ok, {SubsState, _}} =
             SubsState.on_monitor_message(
               {:DOWN, tag, :process, {:no_proc, :no_host}, :normal},
               data
             )
  end
end
