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

defmodule Liblink.Data.Cluster.Discover do
  alias Liblink.Data.Keyword
  alias Liblink.Data.Cluster.Service

  import Liblink.Data.Macros

  defstruct [:restrict, :protocols]

  @type t :: %__MODULE__{}

  @type metadata :: %{optional(binary) => binary}

  @type option ::
          {:retrict, (Service.protocol(), metadata -> boolean)}
          | {:protocols, [Service.protocol()]}

  @spec new!([option]) :: t
  def_bang(:new, 1)

  @spec new() :: {:ok, t}
  @spec new([option]) ::
          {:ok, t}
          | Keyword.fetch_error()
  def new(options \\ []) when is_list(options) do
    restrict_default = fn protocol, metadata ->
      protocol in [:request_response] and is_map(metadata)
    end

    with {:ok, restrict} <- Keyword.fetch_function(options, :restrict, restrict_default),
         {:ok, protocols} <- Keyword.fetch_list(options, :protocols),
         {_, _, true} <- {:protocols, protocols, Enum.all?(protocols, &valid_protocol?/1)},
         {_, _, true} <- {:restrict, restrict, is_function(restrict, 2)} do
      {:ok, %__MODULE__{restrict: restrict, protocols: protocols}}
    else
      {key, value, false} ->
        {:error, {key, {:value, value}}}

      error ->
        error
    end
  end

  @spec valid_protocol?(atom) :: boolean
  defp valid_protocol?(term), do: term == :request_response
end
