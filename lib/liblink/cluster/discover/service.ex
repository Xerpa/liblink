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

defmodule Liblink.Cluster.Discover.Service do
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.RemoteService
  alias Liblink.Data.Cluster.Discover
  alias Liblink.Cluster.Naming
  alias Liblink.Network.Consul
  alias Liblink.Cluster.Database.Mutation

  require Logger

  @type t :: map

  @spec new(Database.t(), Tesla.Client.t(), Cluster.t(), Service.protocol()) :: {:ok, t}
  def new(pid, consul = %Tesla.Client{}, cluster = %Cluster{discover: %Discover{}}, protocol) do
    {:ok, %{database: pid, consul: consul, cluster: cluster, protocol: protocol}}
  end

  @spec halt(t) :: :ok
  def halt(state) do
    :ok = Mutation.del_remote_services(state.database, state.cluster.id, state.protocol)
  end

  @spec exec(t) :: t
  def exec(state) do
    cluster = state.cluster
    protocol = state.protocol
    service_name = Naming.service_name(cluster, protocol)

    _ =
      case Consul.Health.service(state.consul, service_name, state: "passing") do
        {:ok, %{status: 200, body: services}} when is_list(services) ->
          handle_service(state, services)

        _reply ->
          _ = Logger.warn("error reading services from consul")
      end

    state
  end

  @spec handle_service(t, [map]) :: :ok
  defp handle_service(state, reply) when is_list(reply) do
    cluster = state.cluster
    protocol = state.protocol

    services =
      Enum.reduce_while(reply, MapSet.new(), fn health, acc ->
        case build_remote_service(cluster, protocol, health) do
          {:ok, remote_service} ->
            if accept_service?(remote_service) do
              {:cont, MapSet.put(acc, remote_service)}
            else
              {:cont, acc}
            end

          error ->
            _ = Logger.error("error reading services from consul: #{inspect(error)}")
            {:halt, :error}
        end
      end)

    unless services == :error do
      Mutation.add_remote_services(state.database, cluster.id, protocol, services)
    end
  end

  @spec accept_service?(RemoteService.t()) :: boolean
  defp accept_service?(remote_service) do
    remote_service.cluster.discover.restrict.(remote_service.protocol, remote_service.metadata)
  end

  @spec build_remote_service(Cluster.t(), Service.protocol(), map) ::
          {:ok, RemoteService.t()} | :error
  defp build_remote_service(cluster, protocol, health) do
    with true <- is_map(health),
         {:ok, node} when is_map(node) <- Map.fetch(health, "Node"),
         {:ok, service} when is_map(service) <- Map.fetch(health, "Service"),
         {:ok, checks} when is_list(checks) <- Map.fetch(health, "Checks"),
         {:ok, datacenter} when is_binary(datacenter) <- Map.fetch(node, "Datacenter"),
         {:ok, node_addr} when is_binary(node_addr) <- Map.fetch(node, "Address"),
         {:ok, tags} when is_list(tags) <- Map.fetch(service, "Tags"),
         {:ok, metadata} when is_map(metadata) or is_nil(metadata) <- Map.fetch(service, "Meta"),
         {:ok, svc_addr} when is_binary(svc_addr) <- Map.fetch(service, "Address"),
         {:ok, svc_port} when is_integer(svc_port) <- Map.fetch(service, "Port") do
      svc_addr =
        if String.trim(svc_addr) == "" do
          node_addr
        else
          svc_addr
        end

      metadata =
        if is_map(metadata) do
          metadata
        else
          %{}
        end
        |> Map.put("ll-datacenter", datacenter)

      RemoteService.new(
        status: compute_status(checks),
        cluster: cluster,
        protocol: protocol,
        address: svc_addr,
        port: svc_port,
        metadata: metadata,
        tags: tags
      )
    else
      _ ->
        _ =
          Logger.warn(
            "received an invalid data from consul",
            metadata: [entry: health]
          )

        :error
    end
  end

  @spec compute_status([map]) :: :critical | :passing
  defp compute_status(checks) do
    Enum.reduce(checks, :passing, fn check, status ->
      if is_map(check) do
        case Map.fetch(check, "Status") do
          {:ok, "passing"} -> status
          {:ok, "critical"} -> :critical
          {:ok, "warning"} -> status
          :error -> :critical
        end
      else
        :critical
      end
    end)
  end
end
