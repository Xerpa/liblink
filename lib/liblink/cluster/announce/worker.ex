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

defmodule Liblink.Cluster.Announce.Worker do
  alias Liblink.Random
  alias Liblink.Socket
  alias Liblink.Socket.Device
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Monitor
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Data.Consul.Service
  alias Liblink.Data.Consul.TTLCheck
  alias Liblink.Network.Consul.Agent

  import Liblink.Data.Macros

  require Logger

  def_bang(:new, 2)

  def new(consul = %Tesla.Client{}, cluster = %Cluster{announce: %Announce{}}) do
    endpoint = Random.random_tcp_endpoint("0.0.0.0")
    metadata = Map.new(cluster.announce.metadata, fn {k, v} -> {string(k), string(v)} end)
    service_id = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
    service_name = cluster.id

    case Socket.open(:router, "@" <> endpoint) do
      {:ok, device} ->
        with {:ok, ttlcheck} <-
               TTLCheck.new(
                 id: "service:#{service_id}",
                 name: "service:#{service_name}",
                 ttl: [{10, :s}],
                 deregister_critical_service_after: [{1, :h}]
               ),
             {:ok, service} <-
               Service.new(
                 id: service_id,
                 name: service_name,
                 tags: [],
                 meta: metadata,
                 port: Device.bind_port(device),
                 checks: [ttlcheck]
               ) do
          {:ok,
           %{socket: device, consul: consul, cluster: cluster, service0: service, service: nil}}
        else
          _error ->
            :ok = Socket.close(device)
            :error
        end

      _error ->
        :error
    end
  end

  def halt(state) do
    Agent.service_deregister(state.consul, state.service0.id)

    Socket.close(state.socket)
  end

  def exec(state) do
    tags =
      state.cluster.announce.services
      |> Enum.filter(&Monitor.eval(&1.monitor))
      |> Enum.map(& &1.id)
      |> Enum.sort()

    state =
      case service_register(state, %{state.service0 | tags: tags}) do
        {:ok, service} -> %{state | service: service}
        :error -> state
      end

    if state.service do
      check_pass(state, state.service)
    end

    state
  end

  defp service_register(state, service) do
    if state.service == service do
      {:ok, service}
    else
      case Agent.service_register(state.consul, service) do
        {:ok, %{status: 200}} ->
          {:ok, service}

        error ->
          _ =
            Logger.warn(
              "error registering service on consul",
              metadata: [data: [service: service.name], error: error]
            )

          :error
      end
    end
  end

  defp check_pass(state, service) do
    [check] = service.checks

    case Agent.check_pass(state.consul, check.id) do
      {:ok, %{status: 200}} ->
        :ok

      error ->
        _ =
          Logger.warn(
            "error invoking check_pass on consul",
            metadata: [data: [service: service.name, error: error]]
          )

        :error
    end
  end

  defp string(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  defp string(string) when is_binary(string) do
    string
  end
end
