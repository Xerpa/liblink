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

defmodule Liblink.Cluster.DiscoverTest do
  use ExUnit.Case, async: false

  alias Liblink.Cluster.Database
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Discover
  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Database.Mutation

  @moduletag capture_log: true

  describe "announcing a cluster via database" do
    setup do
      {:ok, pid} = Database.start_link([hooks: [Liblink.Cluster.Discover]], [])
      {:ok, tid} = Database.get_tid(pid)
      Database.subscribe(pid, self())

      cluster =
        Cluster.new!(
          id: "liblink",
          discover: Discover.new!(protocols: [:request_response])
        )

      :ok = Test.Liblink.Consul.flush_services()

      {:ok, [database: {pid, tid}, cluster: cluster]}
    end

    test "starts then discover worker when a new cluster is registered", %{
      database: {pid, tid},
      cluster: cluster
    } do
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert_receive {Database, _pid, _tid, _event}
      assert {:ok, discover_pid} = Query.find_cluster_discover(tid, cluster.id, :request_response)
      assert Process.alive?(discover_pid)
    end

    test "terminates the process when cluster is removed", %{
      database: {pid, tid},
      cluster: cluster
    } do
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert_receive {Database, _pid, _tid, _event}
      assert {:ok, discover_pid} = Query.find_cluster_discover(tid, cluster.id, :request_response)
      tag = Process.monitor(discover_pid)
      assert :ok == Mutation.del_cluster(pid, cluster.id)
      assert_receive {:DOWN, ^tag, :process, ^discover_pid, :normal}
      assert :error == Query.find_cluster_discover(tid, cluster.id, :request_response)
    end
  end
end
