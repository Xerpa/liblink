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

defmodule Liblink.Socket.Sendmsg.InitStateTest do
  use ExUnit.Case, async: true

  alias Liblink.Socket.Device
  alias Liblink.Socket.Sendmsg.Fsm
  alias Liblink.Socket.Sendmsg.InitState
  alias Liblink.Socket.Sendmsg.SendState
  alias Liblink.Socket.Sendmsg.TermState

  setup do
    {InitState, data} = Fsm.new()

    {:ok, [data: data]}
  end

  test "can attach", %{data: data} do
    device = %Device{}
    assert {:cont, :ok, {SendState, data}} = InitState.attach(device, data)
    assert device == data.device
  end

  test "can't sendmsg", %{data: data} do
    assert {:cont, {:error, :badstate}, {InitState, _}} = InitState.sendmsg([], data)
    assert {:cont, {:error, :badstate}, {InitState, _}} = InitState.sendmsg([], 0, data)
  end

  test "can halt", %{data: data} do
    assert {:halt, :ok, {TermState, _}} = InitState.halt(data)
  end
end
