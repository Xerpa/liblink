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

defmodule Liblink.ClientTest do
  use ExUnit.Case

  alias Liblink.Client
  alias Liblink.Data.Message
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Data.Cluster.Monitor
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Data.Cluster.Discover
  alias Liblink.Cluster.Database
  alias Liblink.Cluster.Database.Mutation

  @moduletag capture_log: true

  setup env do
    assert :ok = Database.subscribe(Database, self())

    service =
      Service.new!(
        id: "liblink",
        protocol: :request_response,
        monitor: Monitor.new!(monitor: fn -> Map.get(env, :healthy?, true) end),
        exports: Exports.new!(:module, module: Test.Liblink.TestService)
      )

    cluster =
      Cluster.new!(
        id: "liblink",
        discover: Discover.new!(protocols: [:request_response]),
        announce: Announce.new!(services: [service])
      )

    :ok = Test.Liblink.Consul.flush_services()

    :ok = Mutation.add_cluster(cluster)
    assert_receive {Database, _pid, _tid, {:put, {:cluster, _}, _, _}}
    assert_receive {Database, _pid, _tid, {:put, {:announce, "liblink", _}, _, _}}
    assert_receive {Database, _pid, _tid, {:put, {:discover, "liblink", _}, _, _}}
    assert_receive {Database, _pid, _tid, {:put, {:discover, :services, _, _}, _, _}}
    assert_receive {Database, _pid, _tid, {:put, {:discover, :client, _, _}, _, _}}
    assert_receive {Database, _pid, _tid, {:put, {:discover, :device, _, _, _}, _, _}}

    on_exit(fn ->
      Database.subscribe(Database, self())
      :ok = Mutation.del_cluster(cluster.id)
      assert_receive {Database, _pid, _tid, {:del, {:discover, :device, _, _, _}, _}}
      assert_receive {Database, _pid, _tid, {:del, {:discover, :client, _, _}, _}}
      assert_receive {Database, _pid, _tid, {:del, {:discover, :services, _, _}, _}}
      assert_receive {Database, _pid, _tid, {:del, {:discover, "liblink", _}, _}}
      assert_receive {Database, _pid, _tid, {:del, {:announce, "liblink", _}, _}}
      assert_receive {Database, _pid, _tid, {:del, {:cluster, _}, _}}
    end)

    {:ok, [cluster: cluster, service: service]}
  end

  test "call a discovered service", %{cluster: cluster, service: service} do
    assert {:ok, message} = Client.request(cluster.id, service.id, :echo, Message.new(nil))
    assert :success == Message.meta_get(message, "ll-status")
  end

  @tag healthy?: false
  test "client ignore failing services", %{cluster: cluster, service: service} do
    assert {:error, :no_connection} ==
             Client.request(cluster.id, service.id, :echo, Message.new(nil))
  end

  test "requesting an unknown cluster", %{service: service} do
    assert {:error, :no_service} == Client.request("unknown", service.id, :echo, Message.new(nil))
  end

  test "requesting an unknown service", %{cluster: cluster} do
    assert {:error, :no_connection} ==
             Client.request(cluster.id, "unknown", :echo, Message.new(nil))
  end

  test "requesting and unknown function", %{cluster: cluster, service: service} do
    assert {:ok, reply} = Client.request(cluster.id, service.id, :unknown, Message.new(nil))
    assert :failure == Message.meta_get(reply, "ll-status")
    assert {:error, :not_found} == reply.payload
  end

  test "requesting an misbehaving service", %{cluster: cluster, service: service} do
    assert {:ok, reply} = Client.request(cluster.id, service.id, :misbehaving, Message.new(nil))
    assert :failure == Message.meta_get(reply, "ll-status")
    assert {:error, :bad_service} == reply.payload
  end

  test "request a service that raises", %{cluster: cluster, service: service} do
    assert {:ok, reply} =
             Client.request(cluster.id, service.id, :exception, Message.new("except message"))

    assert :failure == Message.meta_get(reply, "ll-status")

    assert {:error, {:except, %RuntimeError{message: "except message"}, _stacktrace}} =
             reply.payload
  end
end
