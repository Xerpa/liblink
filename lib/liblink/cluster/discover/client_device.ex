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

defmodule Liblink.Cluster.Discover.ClientDevice do
  use Liblink.Logger
  use Liblink.Cluster.Database.Hook

  alias Liblink.Cluster.Database.Query
  alias Liblink.Cluster.Protocol.Dealer

  @impl true
  def after_hook(_pid, tid, event) do
    case event do
      {:put, {:discover, :client, cluster_id, protocol}, _prev_client, client} ->
        with :request_response <- protocol,
             devices when is_list(devices) <-
               Query.find_discover_devices(tid, cluster_id, protocol) do
          Enum.each(devices, fn {_endpoint, device} ->
            safe_call(fn -> Dealer.attach(client, device) end)
          end)
        end

      {:put, {:discover, :device, cluster_id, protocol, _endpoint}, prev_device, device} ->
        with :request_response <- protocol,
             {:ok, client} <- Query.find_discover_client(tid, cluster_id, protocol) do
          if prev_device do
            safe_call(fn -> Dealer.detach(client, prev_device) end)
          end

          safe_call(fn -> Dealer.attach(client, device) end)
        end

      {:del, {:discover, :device, cluster_id, protocol, _endpoint}, device} ->
        with :request_response <- protocol,
             {:ok, client} <- Query.find_discover_client(tid, cluster_id, protocol) do
          safe_call(fn -> Dealer.detach(client, device) end)
        end

      _ ->
        :ok
    end
  end

  @spec safe_call((() -> term)) :: :ok | :error
  defp safe_call(call) do
    try do
      call.()

      :ok
    catch
      :exit, {:noproc, {GenServer, :call, _}} ->
        Logger.warn("could not attach device to dealer: noproc")
        :error

      :exit, {:timeout, {GenServer, :call, _}} ->
        Logger.warn("could not attach device to dealer: timeout")
        :error
    end
  end
end
