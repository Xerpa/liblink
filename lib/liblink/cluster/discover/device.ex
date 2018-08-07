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

defmodule Liblink.Cluster.Discover.Device do
  use Liblink.Logger
  use Liblink.Cluster.Database.Hook

  alias Liblink.Socket
  alias Liblink.Cluster.Database.Mutation

  @impl true
  def after_hook(pid, _tid, event) do
    case event do
      {:put, {:discover, :services, cluster_id, protocol}, prev_svcs, next_svcs} ->
        prev_endpoints =
          prev_svcs
          |> Kernel.||(MapSet.new())
          |> MapSet.new(fn service ->
            service.connect_endpoint
          end)

        next_endpoints =
          next_svcs
          |> MapSet.new(fn service ->
            service.connect_endpoint
          end)

        next_endpoints
        |> MapSet.difference(prev_endpoints)
        |> Enum.each(fn endpoint ->
          case Socket.open(:dealer, endpoint) do
            {:ok, device} ->
              Mutation.add_discover_device(
                pid,
                cluster_id,
                protocol,
                endpoint,
                device
              )

            _error ->
              Liblink.Logger.warn("error creating socket for endpoint #{endpoint}")
          end
        end)

        prev_endpoints
        |> MapSet.difference(next_endpoints)
        |> Enum.each(fn endpoint ->
          Mutation.del_discover_device(pid, cluster_id, protocol, endpoint)
        end)

      {:del, {:discover, :services, cluster_id, protocol}, services} ->
        services
        |> Enum.each(fn service ->
          Mutation.del_discover_device(pid, cluster_id, protocol, service.connect_endpoint)
        end)

      {:del, {:discover, :device, _cluster_id, _protocol, _endpoint}, device} ->
        Socket.close(device)

      _ ->
        :ok
    end
  end
end
