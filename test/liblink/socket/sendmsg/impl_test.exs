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

defmodule Liblink.Socket.Sendmsg.ImplTest do
  use ExUnit.Case, async: true

  alias Liblink.Nif
  alias Liblink.Timeout
  alias Liblink.Socket.Device
  alias Liblink.Socket.Sendmsg.Impl

  import Liblink.Random

  setup do
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

    :ok = Nif.signal(router, :cont)

    device = %Device{socket: dealer}

    {:ok, state} = Impl.init()
    {:noreply, state} = Impl.attach(device, :async, state)

    on_exit(fn ->
      Nif.term(dealer)
      Nif.term(router)
    end)

    {:ok, [state: state, router: router]}
  end

  test "send a sync message without deadline", %{state: state} do
    {:reply, :ok, _state} = Impl.sendmsg(["foobar"], :infinity, :sync, state)
  end

  test "send a sync message with deadline", %{state: state} do
    deadline = Timeout.deadline(1, :second)
    {:reply, :ok, _state} = Impl.sendmsg(["foobar"], deadline, :sync, state)
  end

  test "send a message with an experide deadline", %{state: state} do
    deadline = Timeout.deadline(-1, :second)
    {:reply, {:error, :timeout}, _stat} = Impl.sendmsg(["foobar"], deadline, :sync, state)
  end

  test "send an async message without deadline", %{state: state} do
    assert {:noreply, _state} = Impl.sendmsg(["foobar"], :infinity, :async, state)
    assert_receive {:liblink_message, ["foobar", _]}
  end

  test "send an async message with deadline", %{state: state} do
    deadline = Timeout.deadline(1, :second)
    assert {:noreply, _state} = Impl.sendmsg(["foobar"], deadline, :async, state)
    assert_receive {:liblink_message, ["foobar", _]}
  end

  test "send an async message with an expired deadline", %{state: state} do
    deadline = Timeout.deadline(-1, :second)
    assert {:noreply, _state} = Impl.sendmsg(["foobar"], deadline, :async, state)
    refute_receive _
  end
end
