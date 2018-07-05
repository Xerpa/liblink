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

defmodule Liblink.Data.Consul.Check do
  alias Liblink.Data.Consul.TTLCheck

  import Liblink.Data.Macros

  @type t :: TTLCheck.t()

  @type time_t :: {non_neg_integer, :ns, :us, :ms, :s, :h}

  @type option :: TTLCheck.option()

  @spec new!(:ttl, [option]) :: t
  def_bang(:new, 2)

  @spec new(:ttl, [option]) :: {:ok, t} | Keyword.fetch_error()
  def new(:ttl, options) do
    TTLCheck.new(options)
  end

  @spec to_consul(t) :: map
  def to_consul(check = %TTLCheck{}) do
    TTLCheck.to_consul(check)
  end

  @spec time_to_consul(time_t) :: String.t()
  def time_to_consul(time) do
    time
    |> Enum.map(fn {time, unit} -> [Integer.to_string(time), Atom.to_string(unit)] end)
    |> IO.iodata_to_binary()
  end
end
