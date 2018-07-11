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

defmodule Liblink.Data.Cluster.Exports.Module do
  alias Liblink.Data.Keyword

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}

  @type option :: {:module, atom} | {:only, [atom]} | {:except, [atom]}

  defstruct [:module, :restriction]

  def_bang(:new, 1)

  @spec new([option]) :: {:ok, t} | Keyword.fetch_error()
  def new(options) when is_list(options) do
    with {:ok, module} <- Keyword.fetch_atom(options, :module),
         {:ok, only} <- Keyword.fetch_list(options, :only, []),
         {:ok, except} <- Keyword.fetch_list(options, :except, []) do
      Code.ensure_loaded?(module)
      only_restriction = build_restriction(only, true)
      except_restriction = build_restriction(except, false)

      restriction = fn x ->
        only_restriction.(x) and not except_restriction.(x) and function_exported?(module, x, 1)
      end

      {:ok, %__MODULE__{module: module, restriction: restriction}}
    end
  end

  @spec build_restriction(list, boolean) :: (atom -> boolean)
  defp build_restriction([], mzero), do: fn x -> is_atom(x) and mzero end

  defp build_restriction(values, _mzero) when is_list(values) do
    atomset =
      values
      |> Enum.filter(&is_atom/1)
      |> MapSet.new()

    fn x -> is_atom(x) and MapSet.member?(atomset, x) end
  end
end
