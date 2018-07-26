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
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Cluster.FoldServer
  alias Liblink.Cluster.ClusterSupervisor
  alias Liblink.Cluster.Announce.RequestResponse
  alias Liblink.Cluster.Database
  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Database.Mutation

  # XXX: can't make dialyzer accept these function
  @dialyzer [{:nowarn_function, announce_cluster: 4, after_hook: 3}]

  @impl true
  def after_hook(pid, tid, event) do
    case event do
      {:put, key, _, cluster} ->
        with {:cluster, _} <- key,
             %Cluster{announce: %Announce{}} <- cluster,
             {:ok, config} <- Config.new(),
             {:ok, worker} <- RequestResponse.new(Consul.client(config), cluster) do
          proc = %{
            exec: &RequestResponse.exec/1,
            halt: &RequestResponse.halt/1,
            data: worker
          }

          announce_cluster(pid, cluster.id, proc, :request_response)
        end

      {:del, key, value} ->
        with {:cluster, cluster_id} <- key,
             %Cluster{announce: %Announce{}} <- value do
          suppress_cluster(pid, tid, cluster_id, :request_response)
        end
    end
  end

  @spec suppress_cluster(Database.t(), Database.tid(), Cluster.id(), Service.protocol()) :: :ok
  defp suppress_cluster(pid, tid, cluster_id, protocol) do
    with {:ok, announce_pid} <- Query.find_cluster_announce(tid, cluster_id, protocol) do
      FoldServer.halt(announce_pid)
      Mutation.del_cluster_announce(pid, cluster_id, protocol)
    end

    :ok
  end

  @spec announce_cluster(Database.t(), Cluster.id(), FoldServer.proc(), Service.protocol()) ::
          {:ok, pid}
  defp announce_cluster(pid, cluster_id, proc, protocol) do
    init_hook = fn ->
      :ok = Mutation.add_cluster_announce(pid, cluster_id, protocol, self())
    end

    {:ok, _pid} =
      {FoldServer, [proc: proc, interval_in_ms: 1_000, init_hook: init_hook]}
      |> Supervisor.child_spec(shutdown: 10_000, restart: :transient)
      |> ClusterSupervisor.start_child()
  end
end
