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

defmodule Liblink.SocketTest do
  use ExUnit.Case, async: true

  alias Liblink.Socket

  import Liblink.Random

  @moduletag capture_log: true

  setup do
    endpoint = random_inproc_endpoint()

    {:ok, router} = Socket.open(:router, "@" <> endpoint)
    {:ok, dealer} = Socket.open(:dealer, ">" <> endpoint)

    on_exit(fn ->
      Socket.close(dealer)
      Socket.close(router)
    end)

    {:ok, [router: router, dealer: dealer]}
  end

  test "endpoint validation" do
    assert {:error, :bad_endpoint} == Socket.open(:router, "invalid-endpoint")
  end

  test "using blocking api", %{router: router, dealer: dealer} do
    assert :ok == Socket.sendmsg(dealer, "ping")
    assert {:ok, [msgkey, "ping"]} = Socket.recvmsg(router)
    assert :ok == Socket.sendmsg(router, [msgkey, "pong"])
    assert {:ok, ["pong"]} == Socket.recvmsg(dealer)
  end

  test "using consume api", %{router: router, dealer: dealer} do
    assert :ok == Socket.consume(router, self())
    assert :ok == Socket.consume(dealer, self())
    assert :ok == Socket.sendmsg(dealer, "ping")
    assert_receive {Liblink.Socket, :data, [msgkey, "ping"]}
    assert :ok == Socket.sendmsg(router, [msgkey, "pong"])
    assert_receive {Liblink.Socket, :data, ["pong"]}
  end
end
