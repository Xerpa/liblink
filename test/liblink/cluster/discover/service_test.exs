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

defmodule Liblink.Cluster.Discover.ServiceTest do
  use ExUnit.Case, async: false

  alias Liblink.Cluster.Database
  alias Liblink.Data.Consul.Config
  alias Liblink.Network.Consul
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Discover
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Cluster.Discover.Service, as: DiscoverService
  alias Liblink.Cluster.Announce.RequestResponse

  @moduletag capture_log: true

  setup env do
    {:ok, pid} = Database.start_link([hooks: [Liblink.Cluster.Discover]], [])
    {:ok, tid} = Database.get_tid(pid)
    :ok = Database.subscribe(pid, self())

    consul = Consul.client(Config.new!())

    cluster =
      Cluster.new!(
        id: "liblink",
        announce:
          Announce.new!(
            services: [
              Service.new!(
                id: "liblink",
                protocol: :request_response,
                exports: Exports.new!(:module, module: Kernel)
              )
            ]
          ),
        discover:
          Discover.new!(
            restrict: fn _, _ -> Map.get(env, :restrict_return, true) end,
            protocols: [:request_response]
          )
      )

    {:ok, announce_worker} = RequestResponse.new(consul, cluster)

    {:ok, discover_worker} = DiscoverService.new(pid, consul, cluster, :request_response)

    :ok = Test.Liblink.Consul.flush_services(consul)

    on_exit(fn ->
      RequestResponse.halt(announce_worker)
      DiscoverService.halt(discover_worker)
    end)

    {:ok,
     [
       database: {pid, tid},
       consul: consul,
       cluster: cluster,
       discover_worker: discover_worker,
       announce_worker: announce_worker
     ]}
  end

  test "worker state", %{discover_worker: discover_worker, consul: consul, cluster: cluster} do
    assert consul == discover_worker.consul
    assert cluster == discover_worker.cluster
    assert :request_response == discover_worker.protocol
  end

  test "when no service is found", %{
    cluster: cluster,
    discover_worker: discover_worker
  } do
    cluster_id = cluster.id
    DiscoverService.exec(discover_worker)

    assert_receive {Database, _pid, _tid,
                    {:put, {:discover, :services, ^cluster_id, :request_response}, nil, services}}

    assert MapSet.new() == services
  end

  test "when a service is found", %{
    cluster: cluster,
    discover_worker: discover_worker,
    announce_worker: announce_worker
  } do
    cluster_id = cluster.id
    tags = Enum.map(cluster.announce.services, & &1.id)
    meta = Map.put(cluster.announce.metadata, "ll-datacenter", "dc1")

    RequestResponse.exec(announce_worker)
    DiscoverService.exec(discover_worker)

    assert_receive {Database, _pid, _tid,
                    {:put, {:discover, :services, ^cluster_id, :request_response}, nil, services}}

    assert [remote_service] = MapSet.to_list(services)

    assert {:ok, _} =
             :gen_tcp.connect(String.to_charlist(remote_service.address), remote_service.port, [])

    assert :request_response == remote_service.protocol
    assert :passing == remote_service.status
    assert cluster == remote_service.cluster
    assert meta == remote_service.metadata
    assert tags == remote_service.tags
  end

  test "when a service is failing", %{
    consul: consul,
    cluster: cluster,
    discover_worker: discover_worker,
    announce_worker: announce_worker
  } do
    cluster_id = cluster.id
    state = RequestResponse.exec(announce_worker)
    [check] = state.service.checks
    assert {:ok, %{status: 200}} = Consul.Agent.check_fail(consul, check.id)
    DiscoverService.exec(discover_worker)

    assert_receive {Database, _pid, _tid,
                    {:put, {:discover, :services, ^cluster_id, :request_response}, nil, services}}

    assert [%{status: :critical}] = MapSet.to_list(services)
  end

  test "after a service is back up", %{
    consul: consul,
    cluster: cluster,
    discover_worker: discover_worker,
    announce_worker: announce_worker
  } do
    cluster_id = cluster.id
    state = RequestResponse.exec(announce_worker)
    [check] = state.service.checks
    assert {:ok, %{status: 200}} = Consul.Agent.check_fail(consul, check.id)
    discover_worker = DiscoverService.exec(discover_worker)
    assert {:ok, %{status: 200}} = Consul.Agent.check_pass(consul, check.id)
    DiscoverService.exec(discover_worker)

    assert_receive {Database, _pid, _tid,
                    {:put, {:discover, :services, ^cluster_id, :request_response}, nil, services0}}

    assert_receive {Database, _pid, _tid,
                    {:put, {:discover, :services, ^cluster_id, :request_response}, ^services0,
                     services1}}

    assert [%{status: :critical}] = MapSet.to_list(services0)
    assert [%{status: :passing}] = MapSet.to_list(services1)
  end

  @tag restrict_return: false
  test "restrict filters out services", %{
    cluster: cluster,
    discover_worker: discover_worker,
    announce_worker: announce_worker
  } do
    cluster_id = cluster.id
    RequestResponse.exec(announce_worker)
    DiscoverService.exec(discover_worker)

    assert_receive {Database, _pid, _tid,
                    {:put, {:discover, :services, ^cluster_id, :request_response}, nil, services}}

    assert MapSet.new() == services
  end
end
