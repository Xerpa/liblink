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

defmodule Liblink.Socket.Recvmsg.InitStateTest do
  use ExUnit.Case, async: true

  alias Liblink.Socket.Device
  alias Liblink.Socket.Recvmsg.Fsm
  alias Liblink.Socket.Recvmsg.RecvState
  alias Liblink.Socket.Recvmsg.InitState
  alias Liblink.Socket.Recvmsg.TermState

  @moduletag capture_log: true

  test "can halt" do
    {InitState, data} = Fsm.new()

    assert {:halt, :ok, {TermState, _}} = InitState.halt(data)
  end

  test "can attach" do
    {InitState, data} = Fsm.new()

    assert {:cont, :ok, {RecvState, n_data}} = InitState.attach(%Device{}, data)
    assert %Device{} == n_data.device
  end

  test "can't recvmsg" do
    {InitState, data} = Fsm.new()

    assert {:cont, {:error, :badstate}, {InitState, _}} = InitState.recvmsg(data)
  end

  test "can't poll" do
    {InitState, data} = Fsm.new()

    assert {:cont, {:error, :badstate}, {InitState, _}} = InitState.poll(self(), data)
  end

  test "can't halt_poll" do
    {InitState, data} = Fsm.new()

    assert {:cont, {:error, :badstate}, {InitState, _}} =
             InitState.halt_poll(:erlang.make_ref(), data)
  end

  test "can't consume" do
    {InitState, data} = Fsm.new()

    assert {:cont, {:error, :badstate}, {InitState, _}} = InitState.consume(self(), data)
  end

  test "can't receive messages" do
    {InitState, data} = Fsm.new()

    assert {:cont, {:error, :badstate}, {InitState, _}} = InitState.on_liblink_message([], data)
  end

  test "can't receive monitor messages" do
    {InitState, data} = Fsm.new()

    message = {:DOWN, :erlang.make_ref(), :process, self(), :normal}

    assert {:cont, :ok, {InitState, _}} = InitState.on_monitor_message(message, data)
  end
end
