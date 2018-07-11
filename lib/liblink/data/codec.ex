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

defmodule Liblink.Data.Codec do
  import Liblink.Data.Macros

  def_bang(:decode, 1)

  @v0 <<0>>

  @spec decode(term) :: {:ok, term} | :error
  def decode(message) do
    case message do
      [@v0, payload] ->
        try do
          {:ok, :erlang.binary_to_term(payload, [:safe])}
        rescue
          ArgumentError -> :error
        end

      _otherwise ->
        :error
    end
  end

  @spec encode(term) :: [binary]
  def(encode(term)) do
    [@v0, :erlang.term_to_binary(term, compressed: 6)]
  end
end
