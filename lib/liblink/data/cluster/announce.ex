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

defmodule Liblink.Data.Cluster.Announce do
  alias Liblink.Data.Keyword
  alias Liblink.Data.Cluster.Service

  import Liblink.Data.Macros

  defstruct [:metadata, :services]

  @type t :: %__MODULE__{}

  def_bang(:new, 1)

  @type option ::
          {:metadata, %{optional(atom | String.t()) => atom | String.t()}}
          | {:services, [Service.t()]}

  @spec new([option]) ::
          {:ok, t}
          | {:error, {:metadata, :invalid}}
          | {:error, {:services, :invalid}}
          | Keyword.fetch_error()
  def new(options) when is_list(options) do
    with {:ok, metadata} <- Keyword.fetch_map(options, :metadata, %{}),
         {:ok, services} <- Keyword.fetch_list(options, :services, []),
         {_, true} <- {:metadata, valid_metadata?(metadata)},
         {_, true} <- {:services, valid_services?(services)} do
      {:ok, %__MODULE__{metadata: metadata, services: services}}
    else
      {key, false} ->
        {:error, {key, :invalid}}

      error ->
        error
    end
  end

  @spec valid_metadata?(map) :: boolean
  defp valid_metadata?(metadata = %{}) do
    Enum.all?(metadata, fn term ->
      case term do
        {k, v} ->
          (is_atom(k) or is_binary(k)) and (is_atom(v) or is_binary(v))

        _otherwise ->
          false
      end
    end)
  end

  @spec valid_services?(list) :: boolean
  defp valid_services?(services) when is_list(services) do
    if Enum.all?(services, &match?(%Service{}, &1)) do
      all_services = Enum.map(services, & &1.id)
      set_services = MapSet.new(all_services)

      all_services_count = Enum.count(all_services)
      set_services_count = Enum.count(set_services)

      0 < all_services_count and all_services_count == set_services_count
    else
      false
    end
  end
end
