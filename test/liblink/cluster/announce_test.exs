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

defmodule Liblink.Cluster.AnnounceTest do
  use ExUnit.Case, async: false

  alias Liblink.Cluster.Database
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Database.Mutation

  @moduletag capture_log: true

  describe "announcing a cluster via database" do
    setup do
      {:ok, pid} = Database.start_link([hooks: [Liblink.Cluster.Announce]], [])
      {:ok, tid} = Database.get_tid(pid)

      cluster =
        Cluster.new!(
          id: "liblink",
          announce:
            Announce.new!(
              metadata: %{
                "environment" => "production"
              },
              services: [
                Service.new!(
                  id: "liblink",
                  protocol: :request_response,
                  exports: Exports.new!(:module, module: Kernel)
                )
              ]
            )
        )

      :ok = Test.Liblink.Consul.flush_services()

      {:ok, [database: {pid, tid}, cluster: cluster]}
    end

    test "starts then announce worker when a new cluster is registered", %{
      database: {pid, tid},
      cluster: cluster
    } do
      assert :ok == Mutation.add_cluster(pid, cluster)
      db_yield(pid)
      assert {:ok, announce_pid} = Query.find_cluster_announce(tid, cluster.id, :request_response)
      assert Process.alive?(announce_pid)
    end

    test "stops then announce worker when the cluster is removed", %{
      cluster: cluster,
      database: {pid, tid}
    } do
      assert :ok == Mutation.add_cluster(pid, cluster)
      db_yield(pid)
      assert {:ok, announce_pid} = Query.find_cluster_announce(tid, cluster.id, :request_response)
      ref = Process.monitor(announce_pid)

      assert :ok == Mutation.del_cluster(pid, cluster.id)
      assert_receive {:DOWN, ^ref, :process, _object, _reason}

      assert :error == Query.find_cluster_announce(tid, cluster.id, :request_response)
    end
  end

  defp db_yield(pid) do
    Database.fetch_sync(pid, :yield)
  end
end
