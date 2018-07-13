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

defmodule Liblink.Cluster.Discover do
  use Liblink.Cluster.Database.Hook

  alias Liblink.Network.Consul
  alias Liblink.Data.Consul.Config
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Discover
  alias Liblink.Cluster.FoldServer
  alias Liblink.Cluster.ClusterSupervisor
  alias Liblink.Cluster.Discover.Service
  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Database.Mutation

  @impl true
  def after_hook(pid, tid, event) do
    case event do
      {:put, key, _, value} ->
        with {:cluster, _} <- key,
             cluster = %Cluster{discover: %Discover{}} <- value,
             {:ok, config} <- Config.new(),
             {:ok, worker} <- Service.new(pid, Consul.client(config), cluster, :request_response) do
          proc = %{
            exec: &Service.exec/1,
            halt: &Service.halt/1,
            data: worker
          }

          subscribe(pid, cluster.id, proc, :request_response)
        end

      {:del, key, value} ->
        with {:cluster, cluster_id} <- key,
             %Cluster{discover: %Discover{}} <- value do
          unsubscribe(pid, tid, cluster_id, :request_response)
        end

      _ ->
        :ok
    end
  end

  # @spec suppress_cluster(pid, :ets.tid(), term) :: :ok
  defp unsubscribe(pid, tid, cluster_id, protocol) do
    with {:ok, discover_pid} <- Query.find_cluster_discover(tid, cluster_id, protocol) do
      FoldServer.halt(discover_pid)
      Mutation.del_cluster_discover(pid, cluster_id, protocol)
    end

    :ok
  end

  # @spec announce_cluster(pid, Woker.t()) :: {:ok, pid}
  defp subscribe(pid, cluster_id, proc, protocol) do
    init_hook = fn ->
      :ok = Mutation.add_cluster_discover(pid, cluster_id, protocol, self())
    end

    {:ok, _pid} =
      {FoldServer, [proc: proc, init_hook: init_hook, interval_in_ms: 10_000]}
      |> Supervisor.child_spec(shutdown: 10_000, restart: :transient)
      |> ClusterSupervisor.start_child()
  end
end
