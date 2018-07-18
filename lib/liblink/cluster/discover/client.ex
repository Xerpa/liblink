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

defmodule Liblink.Cluster.Discover.Client do
  use Liblink.Cluster.Database.Hook

  alias Liblink.Cluster.Database
  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Database.Mutation
  alias Liblink.Cluster.Protocol.Dealer
  alias Liblink.Cluster.ClusterSupervisor
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service

  @impl true
  def after_hook(pid, tid, event) do
    case event do
      {:put, {:discover, :services, cluster_id, protocol}, nil, _services} ->
        add_client(pid, cluster_id, protocol)

      {:del, {:discover, :services, cluster_id, protocol}, _value} ->
        del_client(pid, tid, cluster_id, protocol)

      _ ->
        :ok
    end
  end

  @spec del_client(Databse.t(), Database.tid(), Cluster.id(), Service.protocol()) :: :ok
  defp del_client(pid, tid, cluster_id, protocol) do
    with {:ok, pid} = Query.find_discover_client(tid, cluster_id, protocol) do
      Dealer.halt(pid)
    end

    Mutation.del_discover_client(pid, cluster_id, protocol)
  end

  @spec add_client(Database.t(), Cluster.id(), Service.protocol()) :: :ok
  defp add_client(pid, cluster_id, protocol) do
    init_hook = fn ->
      :ok = Mutation.add_discover_client(pid, cluster_id, protocol, self())
    end

    case protocol do
      :request_response ->
        {:ok, pid} =
          {Dealer, [init_hook: init_hook]}
          |> Supervisor.child_spec(shutdown: 10_000, restart: :transient)
          |> ClusterSupervisor.start_child()

        pid
    end

    :ok
  end
end
