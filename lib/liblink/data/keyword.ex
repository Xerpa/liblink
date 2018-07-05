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

defmodule Liblink.Data.Keyword do
  import Liblink.Data.Keyword.Macros

  @type fetch_error :: {:error, {Keyword.key(), :not_found | {:value, term}}}

  @spec get(Keyword.t(), Keyword.key()) :: term
  defdelegate get(keyword, key), to: Keyword

  @spec get(Keyword.t(), Keyword.key(), term) :: term
  defdelegate get(keyword, key, value), to: Keyword

  @spec put(Keyword.t(), Keyword.key(), term) :: term
  defdelegate put(keyword, key, value), to: Keyword

  @spec delete(Keyword.t(), Keyword.key()) :: Keyword.t()
  defdelegate delete(keyword, key), to: Keyword

  @spec delete(Keyword.t(), Keyword.key(), term) :: Keyword.t()
  defdelegate delete(keyword, key, value), to: Keyword

  @spec drop(Keyword.t(), [Keyword.key()]) :: Keyword.t()
  defdelegate drop(keyword, keys), to: Keyword

  @spec fetch!(Keyword.t(), Keyword.key()) :: term
  defdelegate fetch!(keyword, key), to: Keyword

  @spec fetch(Keyword.t(), Keyword.key()) :: {:ok, term} | :error
  defdelegate fetch(keyword, key), to: Keyword

  @spec fetch_map(Keyword.t(), Keyword.key()) :: {:ok, map} | fetch_error
  @spec fetch_map(Keyword.t(), Keyword.key(), map) :: {:ok, map} | fetch_error
  @spec maybe_fetch_map(Keyword.t(), Keyword.key(), map | nil) :: {:ok, map | nil} | fetch_error
  def_fetch(:map, :is_map)

  @spec fetch_atom(Keyword.t(), Keyword.key()) :: {:ok, atom} | fetch_error
  @spec fetch_atom(Keyword.t(), Keyword.key(), atom) :: {:ok, atom} | fetch_error
  @spec maybe_fetch_atom(Keyword.t(), Keyword.key(), atom | nil) ::
          {:ok, atom | nil} | fetch_error
  def_fetch(:atom, :is_atom)

  @spec fetch_list(Keyword.t(), Keyword.key()) :: {:ok, list} | fetch_error
  @spec fetch_list(Keyword.t(), Keyword.key(), list) :: {:ok, list} | fetch_error
  @spec maybe_fetch_list(Keyword.t(), Keyword.key(), list | nil) ::
          {:ok, list | nil} | fetch_error
  def_fetch(:list, :is_list)

  @spec fetch_tuple(Keyword.t(), Keyword.key()) :: {:ok, tuple} | fetch_error
  @spec fetch_tuple(Keyword.t(), Keyword.key(), tuple) :: {:ok, tuple} | fetch_error
  @spec maybe_fetch_tuple(Keyword.t(), Keyword.key(), tuple | nil) ::
          {:ok, tuple | nil} | fetch_error
  def_fetch(:tuple, :is_tuple)

  @spec fetch_binary(Keyword.t(), Keyword.key()) :: {:ok, binary} | fetch_error
  @spec fetch_binary(Keyword.t(), Keyword.key(), binary) :: {:ok, binary} | fetch_error
  @spec maybe_fetch_binary(Keyword.t(), Keyword.key(), binary | nil) ::
          {:ok, binary | nil} | fetch_error
  def_fetch(:binary, :is_binary)

  @spec fetch_integer(Keyword.t(), Keyword.key()) :: {:ok, integer} | fetch_error
  @spec fetch_integer(Keyword.t(), Keyword.key(), integer) :: {:ok, integer} | fetch_error
  @spec maybe_fetch_integer(Keyword.t(), Keyword.key(), integer | nil) ::
          {:ok, integer | nil} | fetch_error
  def_fetch(:integer, :is_integer)
end
