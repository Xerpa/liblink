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

defmodule Liblink.Data.Consul.TTLCheck do
  alias Liblink.Data.Keyword
  alias Liblink.Data.Consul.Check

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}

  @type option ::
          {:id, String.t() | nil}
          | {:name, String.t() | nil}
          | {:status, :passing | :warning | :critical}
          | {:ttl, [Consul.time_t()]}
          | {:deregister_critical_service_after, [Consul.time_t()]}

  defstruct [:id, :name, :status, :ttl, :deregister_critical_service_after]

  @spec new() :: t
  def_bang(:new, 0)

  @spec new([option]) :: t
  def_bang(:new, 1)

  @spec new([option]) :: {:ok, t} | Keyword.fetch_error()
  def new(options \\ []) when is_list(options) do
    with {:ok, id} <- Keyword.maybe_fetch_binary(options, :id),
         {:ok, name} <- Keyword.maybe_fetch_binary(options, :name),
         {:ok, ttl} <- Keyword.fetch_list(options, :ttl, [{5, :m}]),
         {:ok, status} <- Keyword.fetch_atom(options, :status, :critical),
         {:ok, deregister_critical_after} <-
           Keyword.fetch_list(options, :deregister_critical_service_after, [{1, :h}]) do
      {:ok,
       %__MODULE__{
         id: id,
         name: name,
         ttl: ttl,
         status: status,
         deregister_critical_service_after: deregister_critical_after
       }}
    end
  end

  @spec to_consul(t) :: map
  def to_consul(check = %__MODULE__{}) do
    %{
      "CheckID" => check.id,
      "Name" => check.name,
      "TTL" => Check.time_to_consul(check.ttl),
      "DeregisterCriticalServiceAfter" =>
        Check.time_to_consul(check.deregister_critical_service_after)
    }
  end
end
