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

defmodule Liblink.Cluster.Discover.ClientTest do
  use ExUnit.Case, async: true
  use Test.Liblink.TestDBHook

  alias Liblink.Cluster.Database
  alias Liblink.Cluster.Database.Mutation

  setup do
    {:ok, pid} = Database.start_link([hooks: [__MODULE__, Liblink.Cluster.Discover.Client]], [])
    {:ok, tid} = Database.get_tid(pid)
    :ok = init_database(pid)

    {:ok, [database: {pid, tid}]}
  end

  test "adds client when services are written", %{database: {pid, _tid}} do
    services = MapSet.new()
    assert :ok == Mutation.add_remote_services(pid, "cluster_id", :request_response, services)
    assert_receive {:put, {:discover, :services, "cluster_id", :request_response}, nil, ^services}
    assert_receive {:put, {:discover, :client, "cluster_id", :request_response}, nil, client_pid}
    assert Process.alive?(client_pid)
  end

  test "removes client when services are removed", %{database: {pid, _tid}} do
    services = MapSet.new()
    assert :ok == Mutation.add_remote_services(pid, "cluster_id", :request_response, services)
    assert_receive {:put, {:discover, :services, "cluster_id", :request_response}, nil, ^services}
    assert_receive {:put, {:discover, :client, "cluster_id", :request_response}, nil, client_pid}
    tag = Process.monitor(client_pid)

    assert :ok == Mutation.del_remote_services(pid, "cluster_id", :request_response)
    assert_receive {:del, {:discover, :services, "cluster_id", :request_response}, ^services}
    assert_receive {:del, {:discover, :client, "cluster_id", :request_response}, ^client_pid}
    assert_receive {:DOWN, ^tag, :process, ^client_pid, :normal}
  end
end
