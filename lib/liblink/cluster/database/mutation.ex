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
  alias Liblink.Cluster.Database

  @spec add_cluster(Database.t(), Cluster.t()) :: :ok | :error
  def add_cluster(db \\ Database, cluster = %Cluster{}) do
    key = {:cluster, cluster.id}
    Database.put_new(db, key, cluster)
  end

  @spec del_cluster(Database.t(), Cluster.id()) :: :ok
  def del_cluster(db \\ Database, cluster_id) do
    key = {:cluster, cluster_id}
    Database.del(db, key)
  end

  @spec add_cluster_announce(Database.t(), Cluster.id(), pid) :: :ok
  def add_cluster_announce(db \\ Database, cluster_id, pid) do
    Database.put_async(db, {:announce, cluster_id}, pid)
  end

  @spec del_cluster_announce(Database.t(), Cluster.id()) :: :ok
  def del_cluster_announce(db \\ Database, cluster_id) do
    Database.del_async(db, {:announce, cluster_id})
  end
end
