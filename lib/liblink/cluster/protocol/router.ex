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
  alias Liblink.Data.Codec
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
    {status, rsp_metadata, payload} =
      with {_, {:ok, {meta, payload}}} when is_map(meta) <- {:codec, Codec.decode(message)},
           {_, {:ok, service_id}} <- {:service, Map.fetch(meta, :service_id)},
           {_, {:ok, service}} <- {:service, Map.fetch(services, service_id)} do
        call_service(cluster, service, meta, payload)
      else
        {:codec, _term} ->
          {:failure, %{}, {:error, :io_error}}

        {:service, _term} ->
          {:failure, %{}, {:error, :not_found}}
      end

    metadata =
      rsp_metadata
      |> Map.new(fn {k, v} -> {String.downcase(to_string(k)), v} end)
      |> Map.put(:date, DateTime.utc_now())
      |> Map.put(:status, status)

    payload = Codec.encode(metadata, payload)

    [routekey | [requestid | payload]]
  end

  @spec call_service(Cluster.t(), Servicet.t(), map, {atom, term}) ::
          {:success, map, term}
          | {:failure, map, {:error, :not_found}}
          | {:failure, map, {:error, :bad_service}}
          | {:failure, map, {:error, {:except, term, term}}}
          | {:failure, map, term}
  defp call_service(
         cluster = %Cluster{},
         service = %Service{},
         req_meta = %{},
         req_payload = {fname, payload}
       ) do
    exports = service.exports

    metadata = [
      cluster: cluster.id,
      service: service.id,
      request: {req_meta, req_payload}
    ]

    if exports.restriction.(fname) do
      try do
        case apply(exports.module, fname, [req_meta, payload]) do
          {:ok, rsp_meta, rsp_payload} when is_map(rsp_meta) ->
            _ =
              Logger.info(
                "processing router request: success",
                metadata: [{:response, {rsp_meta, rsp_payload}} | metadata]
              )

            {:success, rsp_meta, rsp_payload}

          {:error, rsp_meta, rsp_payload} when is_map(rsp_meta) ->
            _ =
              Logger.info(
                "processing router request: failure",
                metadata: [{:response, {%{}, rsp_payload}} | metadata]
              )

            {:failure, rsp_meta, rsp_payload}

          rsp_payload ->
            _ =
              Logger.warn(
                "ignoring response from misbehaving router. response should be {:ok, map, term} | {:error, map, term}",
                metadata: [{:response, {%{}, rsp_payload}} | metadata]
              )

            {:failure, %{}, {:error, :bad_service}}
        end
      rescue
        except ->
          _ = Logger.warn("error executing router", metadata: [{:except, except} | metadata])
          stacktrace = System.stacktrace()
          {:failure, %{}, {:error, {:except, except, stacktrace}}}
      end
    else
      {:failure, %{}, {:error, :not_found}}
    end
  end
end
