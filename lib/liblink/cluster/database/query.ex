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

defmodule Liblink.Cluster.Database.Query do
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service
  alias Liblink.Cluster.Database
  alias Liblink.Socket.Device

  @spec find_cluster(Database.tid(), Cluster.id()) :: {:ok, Cluster.t()} | :error
  def find_cluster(tid, cluster_id) do
    Database.fetch(tid, {:cluster, cluster_id})
  end

  @spec find_cluster_announce(Database.tid(), Cluster.id(), Service.protocol()) ::
          {:ok, pid} | :error
  def find_cluster_announce(tid, cluster_id, protocol) do
    Database.fetch(tid, {:announce, cluster_id, protocol})
  end

  @spec find_cluster_discover(Database.tid(), Cluster.id(), Service.protocol()) ::
          {:ok, pid} | :error
  def find_cluster_discover(tid, cluster_id, protocol) do
    Database.fetch(tid, {:discover, cluster_id, protocol})
  end

  @spec find_remote_services(Database.tid(), Cluster.id(), Service.protocol()) ::
          {:ok, [Service.t()]} | :error
  def find_remote_services(tid, cluster_id, protocol) do
    Database.fetch(tid, {:discover, :services, cluster_id, protocol})
  end

  @spec find_discover_client(Database.tid(), Cluster.id(), Service.protocol()) ::
          {:ok, pid} | :error
  def find_discover_client(tid, cluster_id, protocol) do
    Database.fetch(tid, {:discover, :client, cluster_id, protocol})
  end

  @spec find_discover_device(Database.tid(), Cluster.id(), Service.protocol(), String.t()) ::
          {:ok, Device.t()} | :error
  def find_discover_device(tid, cluster_id, protocol, endpoint) do
    Database.fetch(tid, {:discover, :device, cluster_id, protocol, endpoint})
  end

  @spec find_discover_devices(Database.tid(), Cluster.id(), Service.protocol()) :: [
          {String.t(), Device.t()}
        ]
  def find_discover_devices(tid, cluster_id, protocol) do
    pattern = [
      {{{:discover, :device, :"$1", :"$2", :"$3"}, :"$4"},
       [
         {:is_binary, :"$3"},
         {:"=:=", {:const, protocol}, :"$2"},
         {:"=:=", {:const, cluster_id}, :"$1"}
       ], [{{:"$3", :"$4"}}]}
    ]

    Database.select(tid, pattern)
  end
end
