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

defmodule Liblink.Cluster.DatabaseTest do
  use ExUnit.Case, async: true

  alias Liblink.Cluster.Database

  setup do
    {:ok, pid} = Database.start_link([])
    {:ok, tid} = Database.get_tid(pid)

    {:ok, [pid: pid, tid: tid]}
  end

  test "get on empty database", %{tid: tid} do
    assert is_nil(Database.get(tid, :key))
    assert :default == Database.get(tid, :key, :default)
  end

  test "fetch on empty database", %{tid: tid} do
    assert :error == Database.fetch(tid, :key)
  end

  test "get after put", %{pid: pid, tid: tid} do
    assert :ok == Database.put(pid, :key, :value)
    assert :value == Database.get(tid, :key)
  end

  test "fetch after put", %{pid: pid, tid: tid} do
    assert :ok == Database.put(pid, :key, :value)
    assert {:ok, :value} == Database.fetch(tid, :key)
  end

  test "put after put", %{pid: pid, tid: tid} do
    assert :ok == Database.put(pid, :key, :value0)
    assert :ok == Database.put(pid, :key, :value1)
    assert :value1 == Database.get(tid, :key)
  end

  test "get after put_new", %{pid: pid, tid: tid} do
    assert :ok == Database.put_new(pid, :key, :value)
    assert :value == Database.get(tid, :key)
  end

  test "put_new after put", %{pid: pid, tid: tid} do
    assert :ok == Database.put(pid, :key, :value0)
    assert :error == Database.put_new(pid, :key, :value1)
    assert :value0 == Database.get(tid, :key)
  end

  test "put_new after delete", %{pid: pid} do
    assert :ok == Database.put(pid, :key, :value)
    assert :ok == Database.del(pid, :key)
    assert :ok == Database.put_new(pid, :key, :value)
  end

  test "fetch_sync", %{pid: pid} do
    assert :error = Database.fetch_sync(pid, :key)
  end

  test "fetch_sync after put_async", %{pid: pid} do
    assert :ok == Database.put_async(pid, :key, :value)
    assert {:ok, :value} = Database.fetch_sync(pid, :key)
  end

  test "fetch_sync after del_async", %{pid: pid} do
    assert :ok == Database.put_async(pid, :key, :value)
    assert :ok == Database.del_async(pid, :key)
    assert :error = Database.fetch_sync(pid, :key)
  end
end
