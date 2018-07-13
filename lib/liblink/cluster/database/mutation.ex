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

defmodule Liblink.Cluster.Database.Mutation do
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service
  alias Liblink.Cluster.Database
  alias Liblink.Socket.Device

  @type rservice :: RemoteService.t()

  @spec add_cluster(Cluster.t()) :: :ok | :error
  @spec add_cluster(Database.t(), Cluster.t()) :: :ok | :error
  def add_cluster(db \\ Database, cluster = %Cluster{}) do
    key = {:cluster, cluster.id}
    Database.put_new(db, key, cluster)
  end

  @spec del_cluster(Cluster.id()) :: :ok
  @spec del_cluster(Database.t(), Cluster.id()) :: :ok
  def del_cluster(db \\ Database, cluster_id) when is_binary(cluster_id) do
    key = {:cluster, cluster_id}
    Database.del(db, key)
  end

  @spec add_cluster_announce(Cluster.id(), Service.protocol(), pid) :: :ok
  @spec add_cluster_announce(Database.t(), Cluster.id(), Service.protocol(), pid) :: :ok
  def add_cluster_announce(db \\ Database, cluster_id, protocol, pid)
      when is_binary(cluster_id) and is_atom(protocol) and is_pid(pid) do
    key = {:announce, cluster_id, protocol}
    Database.put_async(db, key, pid)
  end

  @spec del_cluster_announce(Cluster.id(), Service.protocol()) :: :ok
  @spec del_cluster_announce(Database.t(), Cluster.id(), Service.protocol()) :: :ok
  def del_cluster_announce(db \\ Database, cluster_id, protocol)
      when is_binary(cluster_id) and is_atom(protocol) do
    key = {:announce, cluster_id, protocol}
    Database.del_async(db, key)
  end

  @spec add_cluster_discover(Cluster.id(), Service.protocol(), pid) :: :ok
  @spec add_cluster_discover(Database.t(), Cluster.id(), Service.protocol(), pid) :: :ok
  def add_cluster_discover(db \\ Database, cluster_id, protocol, pid)
      when is_binary(cluster_id) and is_atom(protocol) and is_pid(pid) do
    key = {:discover, cluster_id, protocol}
    Database.put_async(db, key, pid)
  end

  @spec del_cluster_discover(Cluster.id(), Service.protocol()) :: :ok
  @spec del_cluster_discover(Database.t(), Cluster.id(), Service.protocol()) :: :ok
  def del_cluster_discover(db \\ Database, cluster_id, protocol)
      when is_binary(cluster_id) and is_atom(protocol) do
    key = {:discover, cluster_id, protocol}
    Database.del_async(db, key)
  end

  @spec add_remote_services(Cluster.id(), Service.protocol(), MapSet.t(rservice)) :: :ok
  @spec add_remote_services(Database.t(), Cluster.id(), Service.protocol(), MapSet.t(rservice)) ::
          :ok
  def add_remote_services(db \\ Database, cluster_id, protocol, services = %{__struct__: MapSet})
      when is_binary(cluster_id) and is_atom(protocol) do
    key = {:discover, :services, cluster_id, protocol}
    Database.put_async(db, key, services)
  end

  @spec del_remote_services(Cluster.id(), Service.protocol()) :: :ok
  @spec del_remote_services(Database.t(), Cluster.id(), Service.protocol()) :: :ok
  def del_remote_services(db \\ Database, cluster_id, protocol)
      when is_binary(cluster_id) and is_atom(protocol) do
    key = {:discover, :services, cluster_id, protocol}
    Database.del_async(db, key)
  end

  @spec add_discover_client(Cluster.id(), Service.protocol(), pid) :: :ok
  @spec add_discover_client(Database.t(), Cluster.id(), Service.protocol(), pid) :: :ok
  def add_discover_client(db \\ Database, cluster_id, protocol, client)
      when is_binary(cluster_id) and is_atom(protocol) and is_pid(client) do
    key = {:discover, :client, cluster_id, protocol}
    Database.put_async(db, key, client)
  end

  @spec del_discover_client(Cluster.id(), Service.protocol(), pid) :: :ok
  @spec add_discover_client(Database.t(), Cluster.id(), Service.protocol()) :: :ok
  def del_discover_client(db \\ Database, cluster_id, protocol) do
    key = {:discover, :client, cluster_id, protocol}
    Database.del_async(db, key)
  end

  @spec add_discover_device(Cluster.id(), Service.protocol(), String.t(), Device.t()) :: :ok
  @spec add_discover_device(
          Database.t(),
          Cluster.id(),
          Service.protocol(),
          String.t(),
          Device.t()
        ) :: :ok
  def add_discover_device(db \\ Database, cluster_id, protocol, endpoint, device = %Device{}) do
    key = {:discover, :device, cluster_id, protocol, endpoint}
    Database.put_async(db, key, device)
  end

  @spec del_discover_device(Cluster.id(), Service.protocol(), String.t()) :: :ok
  @spec del_discover_device(Database.t(), Cluster.id(), Service.protocol(), String.t()) :: :ok
  def del_discover_device(db \\ Database, cluster_id, protocol, endpoint) do
    key = {:discover, :device, cluster_id, protocol, endpoint}
    Database.del_async(db, key)
  end
end
