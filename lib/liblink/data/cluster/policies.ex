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

defmodule Liblink.Data.Cluster.Policies do
  alias Liblink.Data.Keyword

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}

  @type option ::
          {:retries, non_neg_integer()}
          | {:send_timeout_in_ms, pos_integer()}
          | {:recv_timeout_in_ms, pos_integer()}

  defstruct [:retries, :send_timeout_in_ms, :recv_timeout_in_ms]

  @spec new!() :: t
  def_bang(:new, 0)

  @spec new!([option]) :: t
  def_bang(:new, 1)

  @spec new() :: {:ok, t}
  @spec new([option]) :: {:ok, t} | Keyword.fetch_error()
  def new(options \\ []) do
    with {:ok, retries} <- Keyword.fetch_integer(options, :retries, 3),
         {:ok, send_timeout} <- Keyword.fetch_integer(options, :send_timeout_in_ms, 1_000),
         {:ok, recv_timeout} <- Keyword.fetch_integer(options, :recv_timeout_in_ms, 1_000) do
      {:ok,
       %__MODULE__{
         retries: retries,
         send_timeout_in_ms: send_timeout,
         recv_timeout_in_ms: recv_timeout
       }}
    end
  end
end
