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

defmodule Liblink.Socket.MonitorTest do
  use ExUnit.Case

  alias Liblink.Socket
  alias Liblink.Socket.Monitor

  import Liblink.Random

  test "initial state" do
    assert %{procs_count: 0, socks_count: 0} == Monitor.stats()
  end

  test "start monitoring after socket.open" do
    assert {:ok, %{procs_count: 2, socks_count: 1}} =
             Socket.open(:router, "@" <> random_inproc_endpoint(), fn _device ->
               Monitor.stats()
             end)
  end

  test "cleanup state after socket.close" do
    Socket.open(:router, "@" <> random_inproc_endpoint(), fn _device ->
      nil
    end)

    assert %{procs_count: 0, socks_count: 0} == Monitor.stats()
  end
end
