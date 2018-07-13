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

defmodule Liblink.Data.Cluster do
  alias Liblink.Data.Keyword
  alias Liblink.Data.Cluster.Policies
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Data.Cluster.Discover

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}

  @type id :: String.t()

  @type option ::
          {:id, id}
          | {:announce, Announce.t()}
          | {:discover, Discover.t()}
          | {:policies, Policies.t()}

  defstruct [:id, :announce, :discover, :policies]

  @spec new!([option]) :: t
  def_bang(:new, 1)

  @spec new([option]) ::
          {:ok, t} | {:error, {{:announce, :discover}, :not_found}} | Keyword.fetch_error()
  def new(options) when is_list(options) do
    with {:ok, id} <- Keyword.fetch_binary(options, :id),
         {:ok, announce} <- Keyword.maybe_fetch_struct(options, :announce, Announce),
         {:ok, discover} <- Keyword.maybe_fetch_struct(options, :discover, Discover),
         {:ok, policies} <- Keyword.fetch_struct(options, :policies, Policies, Policies.new!()) do
      if !announce and !discover do
        {:error, {{:announce, :discover}, :not_found}}
      else
        {:ok, %__MODULE__{id: id, announce: announce, discover: discover, policies: policies}}
      end
    end
  end
end
