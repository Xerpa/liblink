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

defmodule Liblink.Cluster.Announce do
  use Liblink.Cluster.Database.Hook

  alias Liblink.Network.Consul
  alias Liblink.Data.Consul.Config
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Cluster.FoldServer
  alias Liblink.Cluster.ClusterSupervisor
  alias Liblink.Cluster.Announce.Worker
  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Database.Mutation

  @impl true
  def after_hook(pid, tid, event) do
    case event do
      {:put, key, _, value} ->
        with {:cluster, _} <- key,
             cluster = %Cluster{announce: %Announce{}} <- value,
             {:ok, config} <- Config.new(),
             {:ok, worker} <- Worker.new(Consul.client(config), cluster) do
          announce_cluster(pid, worker)
        end

      {:del, key, value} ->
        with {:cluster, cluster_id} <- key,
             %Cluster{announce: %Announce{}} <- value do
          suppress_cluster(pid, tid, cluster_id)
        end
    end
  end

  @spec suppress_cluster(pid, :ets.tid, term) :: :ok
  defp suppress_cluster(pid, tid, cluster_id) do
    with {:ok, announce_pid} <- Query.find_cluster_announce(tid, cluster_id) do
      FoldServer.halt(announce_pid)
      Mutation.del_cluster_announce(pid, cluster_id)
    end

    :ok
  end

  @spec announce_cluster(pid, Woker.t) :: {:ok, pid}
  defp announce_cluster(pid, worker) do
    proc = %{
      exec: &Worker.exec/1,
      halt: &Worker.halt/1,
      data: worker
    }

    init_callback = fn ->
      :ok = Mutation.add_cluster_announce(pid, worker.cluster.id, self())
    end

    task = %{
      id: :cluster_announce,
      start: {FoldServer, :start_link, [proc, init_callback, 1_000]},
      restart: :transient,
      shutdown: 5_000
    }

    ClusterSupervisor.start_child(task)
  end
end
