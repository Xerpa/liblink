# Copyright (C) 2018  Xerpa

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Liblink.Data.Balance do
  import Liblink.Data.Macros

  @type t :: round_robin_t | weighted_round_robin_t

  @type round_robin_t :: (Enum.t() -> :error | {:ok, term})

  @type weighted_round_robin_t :: (Enum.t() -> :error | {:ok, term})

  @spec round_robin!(Enum.t()) :: :error | {:ok, term}
  def_bang(:round_robin, 1)

  @spec round_robin(Enum.t()) :: :error | {:ok, term}
  def round_robin(terms) do
    if Enum.empty?(terms) do
      :error
    else
      size = Enum.count(terms)
      rand = :rand.uniform(size) - 1

      {:ok, Enum.at(terms, rand)}
    end
  end

  @spec weighted_round_robin!(Enum.t()) :: :error | {:ok, term}
  def_bang(:weighted_round_robin, 1)

  @spec weighted_round_robin(Enum.t()) :: :error | {:ok, term}
  def weighted_round_robin(terms) do
    if Enum.empty?(terms) do
      :error
    else
      {total, terms} =
        Enum.reduce(terms, {0, []}, fn {w, t}, {total, terms} when is_integer(w) ->
          w = max(1, w)

          {w + total, [{w + total, t} | terms]}
        end)

      randn = :rand.uniform(total) - 1

      Enum.reduce_while(terms, :error, fn {w, new_term}, cur_term ->
        if w > randn do
          {:cont, {:ok, new_term}}
        else
          {:halt, cur_term}
        end
      end)
    end
  end
end
