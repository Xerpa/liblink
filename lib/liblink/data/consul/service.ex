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

defmodule Liblink.Data.Consul.Service do
  alias Liblink.Data.Keyword
  alias Liblink.Data.Consul.Check

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}

  @type option ::
          {:id, String.t() | nil}
          | {:name, String.t()}
          | {:port, non_neg_integer() | nil}
          | {:addr, String.t() | nil}
          | {:tags, [atom | String.t()]}
          | {:meta, %{(String.t() | atom) => String.t() | atom}}
          | {:checks, [Check.t()]}

  defstruct [:id, :name, :tags, :meta, :port, :addr, :checks]

  @spec new!([option]) :: t
  def_bang(:new, 1)

  @spec new([option]) :: {:ok, t} | Keyword.fetch_error()
  def new(options) when is_list(options) do
    with {:ok, id} <- Keyword.maybe_fetch_binary(options, :id),
         {:ok, name} <- Keyword.fetch_binary(options, :name),
         {:ok, port} <- Keyword.maybe_fetch_integer(options, :port),
         {:ok, addr} <- Keyword.maybe_fetch_binary(options, :addr),
         {:ok, tags} <- Keyword.fetch_list(options, :tags, []),
         {:ok, meta} <- Keyword.fetch_map(options, :meta, %{}),
         {:ok, checks} <- Keyword.fetch_list(options, :checks, []) do
      {:ok,
       %__MODULE__{
         id: id,
         name: name,
         tags: tags,
         meta: meta,
         port: port,
         addr: addr,
         checks: checks
       }}
    end
  end

  @spec to_consul(t) :: map
  def to_consul(service = %__MODULE__{}) do
    %{
      "ID" => service.id,
      "Name" => service.name,
      "Port" => service.port,
      "Address" => service.addr,
      "Tags" =>
        Enum.map(
          service.tags,
          fn k when is_atom(k) or is_binary(k) ->
            to_string(k)
          end
        ),
      "Meta" =>
        Map.new(
          service.meta,
          fn {k, v} when is_atom(k) or is_binary(k) or (is_atom(v) and is_binary(v)) ->
            {to_string(k), to_string(v)}
          end
        ),
      "Checks" =>
        Enum.map(
          service.checks,
          &Check.to_consul/1
        )
    }
  end
end
