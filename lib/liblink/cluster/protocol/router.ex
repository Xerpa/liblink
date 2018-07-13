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
  alias Liblink.Socket
  alias Liblink.Socket.Device
  alias Liblink.Data.Message
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service

  import Liblink.Data.Macros

  require Logger

  defstruct [:cluster_id, :services]

  @type t :: %__MODULE__{}

  @spec new!(Cluster.id(), [Service.t()]) :: t
  def_bang(:new, 2)

  @spec new(Cluster.id(), [Service.t()]) :: {:ok, t} | :error
  def new(cluster_id, services) do
    services =
      services
      |> Enum.filter(fn service -> service.protocol == :request_response end)
      |> Map.new(fn service -> {service.id, service} end)

    {:ok, %__MODULE__{cluster_id: cluster_id, services: services}}
  end

  @spec handler(iodata, Device.t(), t) :: :ok
  def handler(message, device = %Device{}, router = %__MODULE__{}) do
    _pid =
      spawn(fn ->
        reply = dispatch(message, router)
        :ok = Socket.sendmsg(device, reply)
      end)

    :ok
  end

  @spec dispatch(iodata, t) :: iodata
  def dispatch([routekey | [requestid | message]], state = %__MODULE__{}) do
    {status, reply} =
      with {_, {:ok, message}} <- {:codec, Message.decode(message)},
           {_, {:ok, {service_id, _}}} <-
             {:service, Message.meta_fetch(message, "ll-service-id")},
           {_, {:ok, service}} <- {:service, Map.fetch(state.services, service_id)} do
        call_service(state.cluster_id, service, message)
      else
        {:codec, _term} ->
          {:failure, Message.new({:error, :io_error})}

        {:service, _term} ->
          {:failure, Message.new({:error, :not_found})}
      end

    payload =
      reply
      |> Message.meta_put("ll-status", status)
      |> Message.meta_put("ll-timestamp", DateTime.utc_now())
      |> Message.encode()

    [routekey | [requestid | payload]]
  end

  @spec call_service(Cluster.id(), Servicet.t(), Message.t()) ::
          {:success | :failure, Message.t()}
  defp call_service(cluster_id, service = %Service{}, request = %Message{}) do
    exports = service.exports

    metadata = [
      cluster: cluster_id,
      service: service.id,
      request: request
    ]

    target =
      case Message.meta_fetch(request, "ll-service-id") do
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
