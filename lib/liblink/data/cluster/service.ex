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

defmodule Liblink.Data.Cluster.Service do
  alias Liblink.Data.Keyword
  alias Liblink.Data.Cluster.Monitor
  alias Liblink.Data.Cluster.Exports.Module, as: ExportModule

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}

  @type option ::
          {:id, String.t()}
          | {:protocol, :request_response}
          | {:exports, Exports.t()}
          | {:monitor, Monitor.t()}

  defstruct [:id, :protocol, :exports, :monitor]

  @spec new!([option]) :: t
  def_bang(:new, 1)

  @spec new([option]) :: {:ok, t} | {:error, {:protocol, :invalid}} | Keyword.fetch_error()
  def new(options) when is_list(options) do
    with {:ok, id} <- Keyword.fetch_binary(options, :id),
         {:ok, protocol} <- Keyword.fetch_atom(options, :protocol),
         {:ok, exports} <- Keyword.fetch_struct(options, :exports, [ExportModule]),
         {:ok, monitor} <- Keyword.fetch_struct(options, :monitor, Monitor, Monitor.new!()),
         {_, true} <- {:protocol, protocol == :request_response} do
      {:ok, %__MODULE__{id: id, protocol: protocol, exports: exports, monitor: monitor}}
    else
      {key, false} ->
        {:error, {key, :invalid}}

      error ->
        error
    end
  end
end
