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

defmodule Liblink.Cluster.Announce.RequestResponse do
  use Liblink.Logger

  alias Liblink.Cfg
  alias Liblink.Socket
  alias Liblink.Endpoint
  alias Liblink.Socket.Device
  alias Liblink.Cluster.Naming
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Monitor
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Data.Consul.Service
  alias Liblink.Data.Consul.Check
  alias Liblink.Network.Consul
  alias Liblink.Network.Consul.Agent
  alias Liblink.Cluster.Protocol.Router

  import Liblink.Data.Macros

  # XXX: can't make dialyzer accept these functions
  @dialyzer [{:nowarn_function, new: 2, new!: 2}]

  @type t :: map

  @spec new!(Consul.t(), Cluster.t()) :: t
  def_bang(:new, 2)

  @spec new(Consul.t(), Cluster.t()) :: {:ok, t} | :error
  def new(consul = %Consul{}, cluster = %Cluster{announce: %Announce{}}) do
    net_host = Cfg.protocol_host(:request_response)
    net_port = Cfg.protocol_port(:request_response)
    endpoint = Endpoint.tcp_endpoint(net_host, net_port)
    metadata = Map.new(cluster.announce.metadata, fn {k, v} -> {string(k), string(v)} end)
    service_id = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
    service_name = Naming.service_name(cluster, :request_response)

    case Socket.open(:router, "@" <> endpoint) do
      {:ok, device} ->
        with {:ok, ttlcheck} <-
               Check.new(
                 :ttl,
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
                 addr: net_host,
                 port: Device.bind_port(device),
                 checks: [ttlcheck]
               ),
             {:ok, router} <- Router.new(cluster.id, cluster.announce.services),
             :ok <- Socket.consume(device, {Router, :handler, [device, router]}) do
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

  @spec halt(t) :: :ok
  def halt(state) do
    _ = Agent.service_deregister(state.consul, state.service0.id)

    Socket.close(state.socket)
  end

  @spec exec(t) :: t
  def exec(state) do
    tags =
      state.cluster.announce.services
      |> Enum.filter(fn service ->
        service.protocol == :request_response and Monitor.eval(service.monitor)
      end)
      |> Enum.map(& &1.id)
      |> Enum.sort()

    state =
      case service_register(state, %{state.service0 | tags: tags}) do
        {:ok, service} -> %{state | service: service}
        :error -> state
      end

    case state.service && check_pass(state, state.service) do
      nil -> state
      :ok -> state
      :error -> %{state | service: nil}
    end
  end

  @spec service_register(t, Service.t()) :: {:ok, Service.t()} | :error
  defp service_register(state, service) do
    if state.service == service do
      {:ok, service}
    else
      case Agent.service_register(state.consul, service) do
        {:ok, %{status: 200}} ->
          Liblink.Logger.info(
            "successfully registered service on consul: service=#{service.name}"
          )

          {:ok, service}

        error ->
          Liblink.Logger.warn(
            "error registering service on consul: service=#{service.name} error=#{inspect(error)}"
          )

          :error
      end
    end
  end

  @spec check_pass(t, Service.t()) :: :ok | :error
  defp check_pass(state, service) do
    [check] = service.checks

    case Agent.check_pass(state.consul, check.id) do
      {:ok, %{status: 200}} ->
        :ok

      error ->
        Liblink.Logger.warn(
          "error invoking check_pass on consul. service=#{service.name} error=#{inspect(error)}"
        )

        :error
    end
  end

  @spec string(atom | String.t()) :: String.t()
  defp string(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  defp string(string) when is_binary(string) do
    string
  end
end
