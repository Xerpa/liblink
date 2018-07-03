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

defmodule Liblink.Socket.Sendmsg.SendStateTest do
  use ExUnit.Case, async: true

  alias Liblink.Nif
  alias Liblink.Socket.Device
  alias Liblink.Socket.Sendmsg.Fsm
  alias Liblink.Socket.Sendmsg.InitState
  alias Liblink.Socket.Sendmsg.SendState
  alias Liblink.Socket.Sendmsg.TermState

  setup do
    uniqid = :erlang.unique_integer()

    {:ok, router} =
      Nif.new_socket(
        :router,
        "@inproc://liblink-nif-test-#{uniqid}",
        "inproc://liblink-nif-test-router-#{uniqid}",
        self()
      )

    device = %Device{socket: router}

    {InitState, data} = Fsm.new()
    {:cont, :ok, {SendState, data}} = InitState.attach(device, data)

    on_exit(fn ->
      Nif.term(router)
    end)

    {:ok, [data: data]}
  end

  test "can't attach", %{data: data} do
    assert {:cont, {:error, :badstate}, {SendState, _}} = SendState.attach(%Device{}, data)
  end

  test "can halt", %{data: data} do
    assert {:halt, :ok, {TermState, _}} = SendState.halt(data)
  end

  test "sendmsg without deadline", %{data: data} do
    assert {:cont, :ok, {SendState, _}} = SendState.sendmsg(["foobar"], data)
  end

  test "sendmsg with valid deadline", %{data: data} do
    deadline = :erlang.monotonic_time() + :erlang.convert_time_unit(1, :second, :native)
    assert {:cont, :ok, {SendState, _}} = SendState.sendmsg(["foobar"], deadline, data)
  end

  test "sendmsg with expired deadline", %{data: data} do
    deadline = :erlang.monotonic_time() - :erlang.convert_time_unit(1, :second, :native)

    assert {:cont, {:error, :timeout}, {SendState, _}} =
             SendState.sendmsg(["foobar"], deadline, data)
  end
end
