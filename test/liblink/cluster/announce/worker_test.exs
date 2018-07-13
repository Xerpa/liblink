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

defmodule Liblink.Cluster.Announce.WorkerTest do
  use ExUnit.Case, async: false

  alias Liblink.Socket.Device
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Data.Consul.Config
  alias Liblink.Cluster.Announce.Worker
  alias Liblink.Network.Consul

  @moduletag capture_log: true

  describe "new" do
    setup do
      consul = Consul.client(Config.new!())

      cluster =
        Cluster.new!(
          id: "liblink",
          announce:
            Announce.new!(
              metadata: %{
                "lib" => "link"
              },
              services: [
                Service.new!(
                  id: "liblink",
                  protocol: :request_response,
                  exports: Exports.new!(:module, module: __MODULE__)
                )
              ]
            )
        )

      {:ok, worker} = Worker.new(consul, cluster)

      :ok = Test.Liblink.Consul.flush_services(consul)

      on_exit(fn ->
        Worker.halt(worker)
      end)

      {:ok, [consul: consul, cluster: cluster, worker: worker]}
    end

    test "creates a socket bound to a random port", env do
      assert env.worker.cluster == env.cluster
      assert env.worker.socket
      assert is_integer(env.worker.service0.port)
      assert env.cluster.id == env.worker.service0.name
      assert is_nil(env.worker.service)
      assert 1 == Enum.count(env.worker.service0.checks)
    end

    test "service is announced on consul on exec", env do
      [cluster_service] = env.worker.cluster.announce.services
      new_state = Worker.exec(env.worker)
      service_id = new_state.service.id
      service_name = env.worker.cluster.id
      service_tags = [cluster_service.id]
      service_port = Device.bind_port(env.worker.socket)
      announce_meta = env.worker.cluster.announce.metadata

      assert {:ok, reply = %{status: 200}} =
               Consul.Agent.service(env.consul, new_state.service.id)

      assert %{
               ^service_id => %{
                 "ID" => ^service_id,
                 "Tags" => ^service_tags,
                 "Service" => ^service_name,
                 "Address" => "",
                 "Meta" => ^announce_meta,
                 "Port" => ^service_port
               }
             } = reply.body
    end

    test "halt deregister service", env do
      Worker.exec(env.worker)
      Worker.halt(env.worker)

      assert {:ok, reply} = Consul.Agent.service(env.consul, env.worker.service0.id)
      assert %{} == reply.body
    end

    test "service check is passing after exec", env do
      new_state = Worker.exec(env.worker)
      [check] = new_state.service.checks
      {:ok, reply} = Consul.Health.service(env.consul, new_state.service.name)

      data =
        reply.body
        |> List.first()
        |> Map.update("Checks", [], fn checks ->
          Enum.filter(checks, fn consul_check ->
            check.id == consul_check["CheckID"]
          end)
        end)

      check_id = check.id
      service_id = new_state.service.id

      assert %{
               "Service" => %{
                 "ID" => ^service_id
               },
               "Checks" => [
                 %{
                   "CheckID" => ^check_id,
                   "Status" => "passing"
                 }
               ]
             } = data
    end
  end
end
