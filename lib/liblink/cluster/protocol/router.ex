# Copyright 2018 (c) Xerpa
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Liblink.Cluster.Protocol.Router do
  alias Liblink.Data.Message
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Announce

  import Liblink.Data.Macros

  require Logger

  defstruct [:cluster, :services]

  @type t :: %__MODULE__{}

  @spec new!(Cluster.t()) :: t
  def_bang(:new, 1)

  @spec new(Cluster.t()) :: {:ok, t} | :error
  def new(cluster = %Cluster{announce: %Announce{}}) do
    services =
      cluster.announce.services
      |> Enum.filter(fn service ->
        service.protocol == :request_response
      end)
      |> Map.new(fn service ->
        {service.id, service}
      end)

    if Enum.count(services) == Enum.count(cluster.announce.services) do
      {:ok, %__MODULE__{cluster: cluster, services: services}}
    else
      :error
    end
  end

  def _cluster, do: :error

  @spec dispatch(iodata, t) :: iodata
  def dispatch([routekey | [requestid | message]], %__MODULE__{
        cluster: cluster,
        services: services
      }) do
    {status, reply} =
      with {_, {:ok, message}} <- {:codec, Message.decode(message)},
           {_, {:ok, {service_id, _}}} <- {:service, Message.meta_fetch(message, :service_id)},
           {_, {:ok, service}} <- {:service, Map.fetch(services, service_id)} do
        call_service(cluster, service, message)
      else
        {:codec, _term} ->
          {:failure, Message.new({:error, :io_error})}

        {:service, _term} ->
          {:failure, Message.new({:error, :not_found})}
      end

    metadata =
      reply.metadata
      |> Map.new(fn {k, v} -> {String.downcase(to_string(k)), v} end)
      |> Map.put(:date, DateTime.utc_now())
      |> Map.put(:status, status)

    payload = Message.encode(%{reply | metadata: metadata})

    [routekey | [requestid | payload]]
  end

  @spec call_service(Cluster.t(), Servicet.t(), Message.t()) :: {:success | :failure, Message.t()}
  defp call_service(cluster = %Cluster{}, service = %Service{}, request = %Message{}) do
    exports = service.exports

    metadata = [
      cluster: cluster.id,
      service: service.id,
      request: request
    ]

    target =
      case Message.meta_fetch(request, :service_id) do
        {:ok, {_, target}} when is_atom(target) -> target
        _ -> nil
      end

    if target != nil and exports.restriction.(target) do
      try do
        case apply(exports.module, target, [request]) do
          {:ok, reply = %Message{}} ->
            _ =
              Logger.info(
                "processing router request: success",
                metadata: [{:response, reply} | metadata]
              )

            {:success, reply}

          {:error, reply = %Message{}} ->
            _ =
              Logger.info(
                "processing router request: failure",
                metadata: [{:response, reply} | metadata]
              )

            {:failure, reply}

          _term ->
            _ =
              Logger.warn(
                "ignoring response from misbehaving router. response should be {:ok, Message.t} | {:error, Message.t}",
                metadata: metadata
              )

            {:failure, Message.new({:error, :bad_service})}
        end
      rescue
        except ->
          _ = Logger.warn("error executing router", metadata: [{:except, except} | metadata])
          stacktrace = System.stacktrace()
          {:failure, Message.new({:error, {:except, except, stacktrace}})}
      end
    else
      {:failure, Message.new({:error, :not_found})}
    end
  end
end
