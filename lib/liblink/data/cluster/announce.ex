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

  defstruct [:meta, :services]

  @type t :: %__MODULE__{}

  def_bang(:new, 1)

  @type option ::
          {:meta, %{optional(atom | String.t()) => atom | String.t()}}
          | {:services, [Service.t()]}

  @spec new([option]) ::
          {:ok, t}
          | {:error, {:meta, :invalid}}
          | {:error, {:services, :invalid}}
          | Keyword.fetch_error()
  def new(options) when is_list(options) do
    with {:ok, meta} <- Keyword.fetch_map(options, :meta, %{}),
         {:ok, svcs} <- Keyword.fetch_list(options, :services, []),
         {_, true} <- {:meta, valid_meta?(meta)},
         {_, true} <- {:services, valid_svcs?(svcs)} do
      {:ok, %__MODULE__{meta: meta, services: svcs}}
    else
      {key, false} ->
        {:error, {key, :invalid}}

      error ->
        error
    end
  end

  @spec valid_meta?(map) :: boolean
  defp valid_meta?(meta = %{}) do
    Enum.all?(meta, fn term ->
      case term do
        {k, v} ->
          (is_atom(k) or is_binary(k)) and (is_atom(v) or is_binary(v))

        _otherwise ->
          false
      end
    end)
  end

  @spec valid_svcs?(list) :: boolean
  defp valid_svcs?(svcs) when is_list(svcs) do
    Enum.all?(svcs, fn svc ->
      match?(%Service{}, svc)
    end) and 0 < Enum.count(svcs)
  end
end
