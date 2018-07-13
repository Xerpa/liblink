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

defmodule Liblink.Data.Consul.Config do
  alias Liblink.Data.Keyword

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}
  @type option ::
          {:endpoint, String.t()}
          | {:token, String.t() | nil}
          | {:timeout, non_neg_integer()}

  defstruct [:endpoint, :token, :timeout]

  @spec new!() :: t
  def_bang(:new, 0)

  @spec new!([option]) :: t
  def_bang(:new, 1)

  @spec new() :: {:ok, t}
  def new() do
    new(Application.get_env(:liblink, :consul, []))
  end

  @spec new([option]) :: {:ok, t} | Keyword.fetch_error()
  def new(options) when is_list(options) do
    with {:ok, endpoint} <-
           Keyword.maybe_fetch_binary(options, :endpoint, "http://localhost:8500"),
         {:ok, token} <- Keyword.maybe_fetch_binary(options, :token, nil),
         {:ok, timeout} <- Keyword.fetch_integer(options, :timeout, 1_000) do
      {:ok, %__MODULE__{endpoint: endpoint, token: token, timeout: timeout}}
    end
  end
end
