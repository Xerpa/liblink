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

defmodule Liblink.Data.Cluster.RemoteService do
  alias Liblink.Data.Keyword
  alias Liblink.Data.Cluster

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}

  @type option ::
          {:cluster, Cluster.t()}
          | {:status, :passing | :critical}
          | {:connect_endpoint, String.t()}
          | {:address, String.t()}
          | {:port, pos_integer}
          | {:protocol, atom}
          | {:metadata, map}
          | {:tags, [String.t()]}

  @spec new!([option]) :: t
  def_bang(:new, 1)

  defstruct [:cluster, :address, :port, :protocol, :metadata, :tags, :status, :connect_endpoint]

  @spec new([option]) :: {:ok, t} | Keyword.fetch_error()
  def new(options) when is_list(options) do
    with {:ok, tags} <- Keyword.fetch_list(options, :tags, []),
         {:ok, cluster} <- Keyword.fetch_struct(options, :cluster, Cluster),
         {:ok, address} <- Keyword.fetch_binary(options, :address),
         {:ok, port} <- Keyword.fetch_integer(options, :port),
         {:ok, status} <- Keyword.fetch_atom(options, :status),
         {:ok, protocol} <- Keyword.fetch_atom(options, :protocol),
         {:ok, metadata} <- Keyword.fetch_map(options, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         tags: tags,
         cluster: cluster,
         address: address,
         port: port,
         status: status,
         protocol: protocol,
         metadata: metadata,
         connect_endpoint: connect_endpoint(protocol, address, port)
       }}
    end
  end

  defp connect_endpoint(protocol, address, port) do
    case protocol do
      :request_response ->
        ">tcp://" <> address <> ":" <> to_string(port)

      _ ->
        nil
    end
  end
end
