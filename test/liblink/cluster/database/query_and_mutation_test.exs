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
  use Test.Liblink.TestDBHook

  alias Liblink.Data.Cluster
  alias Liblink.Socket.Device
  alias Liblink.Cluster.Database
  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Database.Mutation

  setup do
    {:ok, pid} = Database.start_link([hooks: [__MODULE__]], [])
    {:ok, tid} = Database.get_tid(pid)
    :ok = init_database(pid)

    {:ok, [pid: pid, tid: tid]}
  end

  describe "cluster" do
    test "find after add", %{pid: pid, tid: tid} do
      cluster = %Cluster{id: "cluster_id"}
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert {:ok, cluster} == Query.find_cluster(tid, cluster.id)
    end

    test "find on empty database", %{tid: tid} do
      cluster = %Cluster{id: "cluster_id"}
      assert :error == Query.find_cluster(tid, cluster.id)
    end

    test "find_ after del", %{pid: pid, tid: tid} do
      cluster = %Cluster{id: "cluster_id"}
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert :ok == Mutation.del_cluster(pid, cluster.id)
      assert :error == Query.find_cluster(tid, cluster.id)
    end

    test "can't update cluster", %{pid: pid} do
      cluster = %Cluster{id: "cluster_id"}
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert :error == Mutation.add_cluster(pid, cluster)
    end

    test "can insert after delete", %{pid: pid} do
      cluster = %Cluster{id: "cluster_id"}
      assert :ok == Mutation.add_cluster(pid, cluster)
      assert :ok == Mutation.del_cluster(pid, cluster.id)
      assert :ok == Mutation.add_cluster(pid, cluster)
    end
  end

  describe "cluster_announce" do
    test "find on empty database", %{tid: tid} do
      assert :error == Query.find_cluster_announce(tid, "cluster_id", :request_response)
    end

    test "find after put", %{pid: pid, tid: tid} do
      assert :ok == Mutation.add_cluster_announce(pid, "cluster_id", :request_response, self())
      assert_receive _
      assert {:ok, self()} == Query.find_cluster_announce(tid, "cluster_id", :request_response)
    end

    test "can replace values", %{pid: pid, tid: tid} do
      some_pid = spawn(fn -> nil end)
      assert :ok == Mutation.add_cluster_announce(pid, "cluster_id", :request_response, self())
      assert :ok == Mutation.add_cluster_announce(pid, "cluster_id", :request_response, some_pid)
      assert_receive _
      assert_receive _
      assert {:ok, some_pid} == Query.find_cluster_announce(tid, "cluster_id", :request_response)
    end

    test "find after del", %{pid: pid, tid: tid} do
      assert :ok == Mutation.add_cluster_announce(pid, "cluster_id", :request_response, self())
      assert :ok == Mutation.del_cluster_announce(pid, "cluster_id", :request_response)
      assert_receive _
      assert_receive _
      assert :error == Query.find_cluster_announce(tid, "cluster_id", :request_response)
    end
  end

  describe "cluster_discover" do
    test "find on empty database", %{tid: tid} do
      assert :error == Query.find_cluster_discover(tid, "cluster_id", :request_response)
    end

    test "find after put", %{pid: pid, tid: tid} do
      assert :ok == Mutation.add_cluster_discover(pid, "cluster_id", :request_response, self())
      assert_receive _
      assert {:ok, self()} == Query.find_cluster_discover(tid, "cluster_id", :request_response)
    end

    test "can replace values", %{pid: pid, tid: tid} do
      some_pid = spawn(fn -> nil end)
      assert :ok == Mutation.add_cluster_discover(pid, "cluster_id", :request_response, self())
      assert :ok == Mutation.add_cluster_discover(pid, "cluster_id", :request_response, some_pid)
      assert_receive _
      assert_receive _
      assert {:ok, some_pid} == Query.find_cluster_discover(tid, "cluster_id", :request_response)
    end

    test "find after del", %{pid: pid, tid: tid} do
      assert :ok == Mutation.add_cluster_discover(pid, "cluster_id", :request_response, self())
      assert :ok == Mutation.del_cluster_discover(pid, "cluster_id", :request_response)
      assert_receive _
      assert_receive _
      assert :error == Query.find_cluster_discover(tid, "cluster_id", :request_response)
    end
  end

  describe "remote_services" do
    test "find on empty database", %{tid: tid} do
      assert :error == Query.find_remote_services(tid, "cluster_id", :request_response)
    end

    test "find after put", %{pid: pid, tid: tid} do
      services = MapSet.new([:service])
      assert :ok == Mutation.add_remote_services(pid, "cluster_id", :request_response, services)
      assert_receive _
      assert {:ok, services} == Query.find_remote_services(tid, "cluster_id", :request_response)
    end
  end

  describe "discover_client" do
    test "find on empty database", %{tid: tid} do
      assert :error == Query.find_discover_client(tid, "cluster_id", :request_response)
    end

    test "find after put", %{pid: pid, tid: tid} do
      assert :ok == Mutation.add_discover_client(pid, "cluster_id", :request_response, self())
      assert_receive _
      assert {:ok, self()} == Query.find_discover_client(tid, "cluster_id", :request_response)
    end

    test "find after del", %{pid: pid, tid: tid} do
      assert :ok == Mutation.add_discover_client(pid, "cluster_id", :request_response, self())
      assert :ok == Mutation.del_discover_client(pid, "cluster_id", :request_response)
      assert_receive _
      assert_receive _
      assert :error == Query.find_discover_client(tid, "cluster_id", :request_response)
    end
  end

  describe "discover_device" do
    test "find on empty database", %{tid: tid} do
      assert :error = Query.find_discover_device(tid, "cluster_id", :request_response, "endpoint")
    end

    test "find_all on empty database", %{tid: tid} do
      assert [] == Query.find_discover_devices(tid, "cluster_id", :request_response)
    end

    test "find after put", %{pid: pid, tid: tid} do
      assert :ok ==
               Mutation.add_discover_device(
                 pid,
                 "cluster_id",
                 :request_response,
                 "endpoint",
                 %Device{}
               )

      assert_receive _

      assert {:ok, %Device{}} ==
               Query.find_discover_device(tid, "cluster_id", :request_response, "endpoint")
    end

    test "find_all after one put", %{pid: pid, tid: tid} do
      assert :ok ==
               Mutation.add_discover_device(
                 pid,
                 "cluster_id",
                 :request_response,
                 "endpoint",
                 %Device{}
               )

      assert_receive _

      assert [{"endpoint", %Device{}}] ==
               Query.find_discover_devices(tid, "cluster_id", :request_response)
    end

    test "find_all after two put", %{pid: pid, tid: tid} do
      assert :ok ==
               Mutation.add_discover_device(
                 pid,
                 "cluster_id",
                 :request_response,
                 "endpoint0",
                 %Device{}
               )

      assert :ok ==
               Mutation.add_discover_device(
                 pid,
                 "cluster_id",
                 :request_response,
                 "endpoint1",
                 %Device{}
               )

      assert_receive _
      assert_receive _

      all_devices = Enum.sort(Query.find_discover_devices(tid, "cluster_id", :request_response))

      assert [{"endpoint0", %Device{}}, {"endpoint1", %Device{}}] == all_devices
    end
  end
end
