# Copyright (C) 2018  Xerpa

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Liblink.Cluster.FoldServerTest do
  use ExUnit.Case, async: true

  alias Liblink.Cluster.FoldServer

  setup do
    pid = self()

    proc = %{
      exec: fn {:cont, x} -> send(pid, {:cont, x + 1}) end,
      halt: fn {:cont, x} -> send(pid, {:halt, x}) end,
      data: {:cont, 0}
    }

    {:ok, [proc: proc]}
  end

  test "invokes init hook in the init context", %{proc: proc} do
    pid = self()

    {:ok, pid} =
      FoldServer.start_link(
        proc: proc,
        init_hook: fn -> send(pid, {:init, self()}) end,
        interval_in_ms: 10_000
      )

    assert_receive {:init, ^pid}
  end

  test "invokes exec before first timer", %{proc: proc} do
    {:ok, _pid} = FoldServer.start_link(proc: proc, interval_in_ms: 10_000)

    assert_receive {:cont, 1}
  end

  test "accumulates data on exec", %{proc: proc} do
    {:ok, _pid} = FoldServer.start_link(proc: proc, interval_in_ms: 10)

    assert_receive {:cont, 1}
    assert_receive {:cont, 2}
  end

  test "invokes halt on termination", %{proc: proc} do
    {:ok, pid} = FoldServer.start_link(proc: proc, interval_in_ms: 10_000)

    tag = Process.monitor(pid)

    Process.exit(pid, :normal)
    assert_receive {:cont, 1}
    assert_receive {:halt, 1}
    assert_receive {:DOWN, ^tag, :process, ^pid, :normal}
  end

  test "halt message terminates the server", %{proc: proc} do
    {:ok, pid} = FoldServer.start_link(proc: proc, interval_in_ms: 10_000)

    tag = Process.monitor(pid)

    FoldServer.halt(pid)
    assert_receive {:cont, 1}
    assert_receive {:halt, 1}
    assert_receive {:DOWN, ^tag, :process, ^pid, :normal}
  end
end
