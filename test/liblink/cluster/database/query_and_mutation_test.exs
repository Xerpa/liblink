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

defmodule Liblink.Cluster.Database.QueryAndMutationTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Cluster
  alias Liblink.Cluster.Database
  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Database.Mutation

  setup do
    {:ok, pid} = Database.start_link([])
    {:ok, tid} = Database.get_tid(pid)

    {:ok, [pid: pid, tid: tid]}
  end

  describe "cluster" do
    test "find after add", %{pid: pid, tid: tid} do
      cluster = %Cluster{}
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert {:ok, cluster} == Query.find_cluster(tid, cluster.id)
    end

    test "find on empty database", %{tid: tid} do
      cluster = %Cluster{}
      assert :error == Query.find_cluster(tid, cluster.id)
    end

    test "find_ after del", %{pid: pid, tid: tid} do
      cluster = %Cluster{}
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert :ok == Mutation.del_cluster(pid, cluster.id)
      assert :error == Query.find_cluster(tid, cluster.id)
    end

    test "can't update cluster", %{pid: pid} do
      cluster = %Cluster{}
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert :error == Mutation.add_cluster(pid, cluster)
    end

    test "can insert after delete", %{pid: pid} do
      cluster = %Cluster{}
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert :ok == Mutation.del_cluster(pid, cluster.id)
      assert :ok == Mutation.add_cluster(pid, cluster)
    end
  end

  describe "cluster_announce" do
    test "find on empty database", %{tid: tid} do
      assert :error == Query.find_cluster_announce(tid, :cluster_id)
    end

    test "find after put", %{pid: pid, tid: tid} do
      assert :ok == Mutation.add_cluster_announce(pid, :cluster_id, :value)
      db_yield(pid)
      assert {:ok, :value} == Query.find_cluster_announce(tid, :cluster_id)
    end

    test "can replace values", %{pid: pid, tid: tid} do
      assert :ok == Mutation.add_cluster_announce(pid, :cluster_id, :value0)
      assert :ok == Mutation.add_cluster_announce(pid, :cluster_id, :value1)
      db_yield(pid)
      assert {:ok, :value1} == Query.find_cluster_announce(tid, :cluster_id)
    end

    test "find after del", %{pid: pid, tid: tid} do
      assert :ok == Mutation.add_cluster_announce(pid, :cluster_id, :value)
      assert :ok == Mutation.del_cluster_announce(pid, :cluster_id)
      db_yield(pid)
      assert :error == Query.find_cluster_announce(tid, :cluster_id)
    end
  end

  defp db_yield(pid) do
    Database.fetch_async(pid, :poll)
    assert_receive _
  end
end
