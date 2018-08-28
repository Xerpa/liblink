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
  use Liblink.Logger

  alias Liblink.Socket
  alias Liblink.Socket.Device
  alias Liblink.Data.Message
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service

  import Liblink.Data.Macros

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
    reply =
      with {_, {:ok, message}} <- {:codec, Message.decode(message)},
           {_, {:ok, {service_id, _}}} <-
             {:service, Message.meta_fetch(message, "ll-service-id")},
           {_, {:ok, service}} <- {:service, Map.fetch(state.services, service_id)} do
        call_service(service, message)
      else
        {:codec, _term} ->
          {:error, :io_error, Message.new(nil)}

        {:service, _term} ->
          {:error, :not_found, Message.new(nil)}
      end

    payload = Message.encode(reply)

    [routekey | [requestid | payload]]
  end

  @spec call_service(Service.t(), Message.t()) :: {:ok, Message.t()} | {:error, atom, Message.t()}
  defp call_service(service = %Service{}, request = %Message{}) do
    exports = service.exports

    target =
      case Message.meta_fetch(request, "ll-service-id") do
        {:ok, {_, target}} when is_atom(target) -> target
        _ -> nil
      end

    if target != nil and exports.restriction.(target) do
      if function_exported?(exports.module, :__advise__, 2) do
        apply(exports.module, :__advise__, [target, request])
      else
        Liblink.Middleware.advise_ext(exports.module, target, request)
      end
    else
      {:error, :not_found}
    end
  end
end
