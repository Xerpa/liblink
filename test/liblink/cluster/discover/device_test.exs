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

defmodule Liblink.Cluster.Discover.DeviceTest do
  use ExUnit.Case, async: true
  use Test.Liblink.TestDBHook

  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.RemoteService
  alias Liblink.Socket.Device
  alias Liblink.Cluster.Database
  alias Liblink.Cluster.Database.Mutation

  setup do
    {:ok, pid} = Database.start_link([hooks: [__MODULE__, Liblink.Cluster.Discover.Device]], [])
    {:ok, tid} = Database.get_tid(pid)
    :ok = init_database(pid)

    {:ok, [database: {tid, pid}]}
  end

  test "does nothing when there is no service", %{database: {_tid, pid}} do
    assert :ok == Mutation.add_remote_services(pid, "cluster_id", :request_response, MapSet.new())

    key = {:discover, :services, "cluster_id", :request_response}
    assert_receive {:put, ^key, nil, _}
    refute_receive _
  end

  test "creates a device when a new service is registered", %{database: {_tid, pid}} do
    service =
      RemoteService.new!(
        address: "127.0.0.1",
        port: 4000,
        protocol: :request_response,
        status: :passing,
        cluster: %Cluster{}
      )

    assert :ok ==
             Mutation.add_remote_services(
               pid,
               "cluster_id",
               :request_response,
               MapSet.new([service])
             )

    key = {:discover, :services, "cluster_id", :request_response}
    assert_receive {:put, ^key, nil, _}

    key = {:discover, :device, "cluster_id", :request_response, service.connect_endpoint}
    assert_receive {:put, ^key, nil, %Device{}}
  end

  test "create a device when service gets updated", %{database: {_tid, pid}} do
    service0 =
      RemoteService.new!(
        address: "127.0.0.1",
        port: 4000,
        protocol: :request_response,
        status: :passing,
        cluster: %Cluster{}
      )

    service1 =
      RemoteService.new!(
        address: "127.0.0.1",
        port: 4001,
        protocol: :request_response,
        status: :passing,
        cluster: %Cluster{}
      )

    assert :ok =
             Mutation.add_remote_services(
               pid,
               "cluster_id",
               :request_response,
               MapSet.new([service0])
             )

    key = {:discover, :services, "cluster_id", :request_response}
    assert_receive {:put, ^key, nil, _}

    key = {:discover, :device, "cluster_id", :request_response, service0.connect_endpoint}
    assert_receive {:put, ^key, nil, _}

    assert :ok ==
             Mutation.add_remote_services(
               pid,
               "cluster_id",
               :request_response,
               MapSet.new([service1, service0])
             )

    key = {:discover, :services, "cluster_id", :request_response}
    assert_receive {:put, ^key, _, _}

    key = {:discover, :device, "cluster_id", :request_response, service1.connect_endpoint}
    assert_receive {:put, ^key, nil, _}
  end

  test "can insert twice but device won't be recreated", %{database: {_, pid}} do
    service =
      RemoteService.new!(
        address: "127.0.0.1",
        port: 4000,
        protocol: :request_response,
        status: :passing,
        cluster: %Cluster{}
      )

    assert :ok ==
             Mutation.add_remote_services(
               pid,
               "cluster_id",
               :request_response,
               MapSet.new([service])
             )

    assert :ok ==
             Mutation.add_remote_services(
               pid,
               "cluster_id",
               :request_response,
               MapSet.new([service])
             )

    key = {:discover, :services, "cluster_id", :request_response}
    assert_receive {:put, ^key, nil, _}
    assert_receive {:put, ^key, _, _}

    key = {:discover, :device, "cluster_id", :request_response, service.connect_endpoint}
    assert_receive {:put, ^key, nil, %Device{}}
    refute_receive {:put, ^key, _, _}
  end

  test "remove services that are removed", %{database: {_, pid}} do
    service =
      RemoteService.new!(
        address: "127.0.0.1",
        port: 4000,
        protocol: :request_response,
        status: :passing,
        cluster: %Cluster{}
      )

    assert :ok ==
             Mutation.add_remote_services(
               pid,
               "cluster_id",
               :request_response,
               MapSet.new([service])
             )

    assert :ok ==
             Mutation.add_remote_services(
               pid,
               "cluster_id",
               :request_response,
               MapSet.new()
             )

    key = {:discover, :services, "cluster_id", :request_response}
    assert_receive {:put, ^key, nil, _}
    assert_receive {:put, ^key, _, _}

    key = {:discover, :device, "cluster_id", :request_response, service.connect_endpoint}
    assert_receive {:put, ^key, nil, %Device{}}
    assert_receive {:del, ^key, %Device{}}
  end
end
