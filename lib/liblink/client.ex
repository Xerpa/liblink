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

defmodule Liblink.Client do
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Message
  alias Liblink.Cluster.Database
  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Protocol.Dealer

  import Liblink.Guards

  @spec request(Cluster.id(), Service.id(), atom, Message.t(), timeout) ::
          {:ok, Message.t()}
          | {:error, :timeout}
          | {:error, :io_error}
          | {:error, :no_service}
          | {:error, :no_connection}
  def request(cluster_id, service_id, service_fn, message = %Message{}, timeout_in_ms \\ 1_000)
      when is_binary(cluster_id) and is_binary(service_id) and is_atom(service_fn) and
             is_timeout(timeout_in_ms) do
    with {_, {:ok, tid}} <- {:sys_error, Database.get_tid(Database)},
         {_, {:ok, services}} <-
           {:no_service, Query.find_remote_services(tid, cluster_id, :request_response)},
         {_, devices} <-
           {:no_service, Query.find_discover_devices(tid, cluster_id, :request_response)},
         {_, {:ok, client}} <-
           {:no_service, Query.find_discover_client(tid, cluster_id, :request_response)} do
      request_id =
        :crypto.strong_rand_bytes(16)
        |> Base.encode16(case: :lower)

      endpoints =
        Enum.reduce(services, MapSet.new(), fn svc, acc ->
          tags = MapSet.new(svc.tags)

          if svc.status == :passing and MapSet.member?(tags, service_id) do
            MapSet.put(acc, svc.connect_endpoint)
          else
            acc
          end
        end)

      devices =
        devices
        |> Enum.reduce(MapSet.new(), fn {endpoint, device}, acc ->
          if MapSet.member?(endpoints, endpoint) do
            MapSet.put(acc, device)
          else
            acc
          end
        end)

      message =
        message
        |> Message.meta_put("ll-timestamp", DateTime.utc_now())
        |> Message.meta_put("ll-request-id", request_id)
        |> Message.meta_put("ll-service-id", {service_id, service_fn})

      Dealer.request(
        client,
        message,
        restrict_fn: &MapSet.intersection(&1, devices),
        timeout_in_ms: timeout_in_ms
      )
    else
      {tag, :error} ->
        {:error, tag}
    end
  end
end
