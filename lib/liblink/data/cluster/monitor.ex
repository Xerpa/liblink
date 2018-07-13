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

defmodule Liblink.Data.Cluster.Monitor do
  alias Liblink.Data.Keyword

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}

  @type option :: {:monitor, (() -> boolean)}

  defstruct [:monitor]

  @spec new!() :: t
  def_bang(:new, 0)

  @spec new!([option]) :: t
  def_bang(:new, 1)

  @spec new() :: {:ok, t}
  @spec new([option]) :: {:ok, t} | {:error, {:monitor, :invalid}} | Keyword.fetch_error()
  def new(options \\ []) when is_list(options) do
    with {:ok, monitor} <- Keyword.fetch_function(options, :monitor, fn -> true end),
         {_, true} <- {:monitor, is_function(monitor, 0)} do
      {:ok, %__MODULE__{monitor: monitor}}
    else
      {key, false} ->
        {:error, {key, :invalid}}

      error ->
        error
    end
  end

  def eval(monitor = %__MODULE__{}) do
    monitor.monitor.()
  end
end
