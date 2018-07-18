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

defmodule Liblink.Cluster.Discover.ClientDeviceTest do
  use ExUnit.Case, async: true

  alias Liblink.Socket
  alias Liblink.Cluster.Protocol.Dealer
  alias Liblink.Cluster.Database
  alias Liblink.Cluster.Database.Mutation

  import Liblink.Random

  @moduletag capture_log: true

  setup do
    {:ok, pid} = Database.start_link([hooks: [Liblink.Cluster.Discover.ClientDevice]], [])
    :ok = Database.subscribe(pid, self())

    {:ok, dealer} = Dealer.start_link()

    {:ok, tid} = Database.get_tid(pid)

    {:ok, device} = Socket.open(:dealer, ">" <> random_inproc_endpoint())

    on_exit(fn ->
      Socket.close(device)
    end)

    {:ok, [database: {pid, tid}, dealer: dealer, device: device]}
  end

  test "can register device before the client", %{
    database: {pid, _tid},
    dealer: dealer,
    device: device
  } do
    Mutation.add_discover_device(
      pid,
      "cluster_id",
      :request_response,
      "endpoint",
      device
    )

    Mutation.add_discover_client(pid, "cluster_id", :request_response, dealer)

    key = {:discover, :device, "cluster_id", :request_response, "endpoint"}
    assert_receive {Database, _pid, _tid, {:put, ^key, nil, ^device}}

    key = {:discover, :client, "cluster_id", :request_response}
    assert_receive {Database, _pid, _tid, {:put, ^key, nil, ^dealer}}

    assert MapSet.new([device]) == Dealer.devices(dealer)
  end

  test "register devices on client update", %{
    database: {pid, _tid},
    dealer: dealer,
    device: device
  } do
    Mutation.add_discover_client(pid, "cluster_id", :request_response, dealer)

    Mutation.add_discover_device(
      pid,
      "cluster_id",
      :request_response,
      "endpoint",
      device
    )

    Dealer.detach(dealer, device)

    Mutation.add_discover_client(pid, "cluster_id", :request_response, dealer)

    key = {:discover, :device, "cluster_id", :request_response, "endpoint"}
    assert_receive {Database, _pid, _tid, {:put, ^key, nil, ^device}}

    key = {:discover, :client, "cluster_id", :request_response}
    assert_receive {Database, _pid, _tid, {:put, ^key, nil, ^dealer}}
    assert_receive {Database, _pid, _tid, {:put, ^key, ^dealer, ^dealer}}

    assert MapSet.new([device]) == Dealer.devices(dealer)
  end

  test "can register device after the client", %{
    database: {pid, _tid},
    dealer: dealer,
    device: device
  } do
    assert :ok == Mutation.add_discover_client(pid, "cluster_id", :request_response, dealer)

    key = {:discover, :client, "cluster_id", :request_response}
    assert_receive {Database, _pid, _tid, {:put, ^key, nil, ^dealer}}

    assert :ok ==
             Mutation.add_discover_device(
               pid,
               "cluster_id",
               :request_response,
               "endpoint",
               device
             )

    key = {:discover, :device, "cluster_id", :request_response, "endpoint"}
    assert_receive {Database, _pid, _tid, {:put, ^key, nil, ^device}}

    assert MapSet.new([device]) == Dealer.devices(dealer)
  end

  test "remove the device from the client", %{
    database: {pid, _tid},
    dealer: dealer,
    device: device
  } do
    assert :ok == Mutation.add_discover_client(pid, "cluster_id", :request_response, dealer)
    key = {:discover, :client, "cluster_id", :request_response}
    assert_receive {Database, _pid, _tid, {:put, ^key, nil, ^dealer}}

    assert :ok ==
             Mutation.add_discover_device(
               pid,
               "cluster_id",
               :request_response,
               "endpoint",
               device
             )

    key = {:discover, :device, "cluster_id", :request_response, "endpoint"}
    assert_receive {Database, _pid, _tid, {:put, ^key, nil, ^device}}

    assert :ok ==
             Mutation.del_discover_device(
               pid,
               "cluster_id",
               :request_response,
               "endpoint"
             )

    assert_receive {Database, _pid, _tid, {:del, ^key, ^device}}

    assert MapSet.new() == Dealer.devices(dealer)
  end
end
