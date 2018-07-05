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

  @spec fetch_function(Keyword.t(), Keyword.key()) :: {:ok, function} | fetch_error
  @spec fetch_function(Keyword.t(), Keyword.key(), function) :: {:ok, function} | fetch_error
  @spec maybe_fetch_function(Keyword.t(), Keyword.key(), function | nil) ::
          {:ok, function} | fetch_error
  def_fetch(:function, :is_function)

  @spec fetch_integer(Keyword.t(), Keyword.key()) :: {:ok, integer} | fetch_error
  @spec fetch_integer(Keyword.t(), Keyword.key(), integer) :: {:ok, integer} | fetch_error
  @spec maybe_fetch_integer(Keyword.t(), Keyword.key(), integer | nil) ::
          {:ok, integer | nil} | fetch_error
  def_fetch(:integer, :is_integer)

  @spec fetch_struct(Keyword.t(), Keyword.key(), atom | [atom]) :: {:ok, struct} | fetch_error
  def fetch_struct(keyword, key, struct_or_struct_list)
      when is_list(keyword) and is_atom(key) and
             (is_atom(struct_or_struct_list) or is_list(struct_or_struct_list)) do
    case fetch_map(keyword, key) do
      {:ok, value = %{__struct__: struct}} ->
        valid? =
          (is_atom(struct_or_struct_list) and struct == struct_or_struct_list) or
            (is_list(struct_or_struct_list) and Enum.member?(struct_or_struct_list, struct))

        if valid? do
          {:ok, value}
        else
          {:error, {key, {:value, value}}}
        end

      {:ok, value} ->
        {:error, {key, {:value, value}}}

      result ->
        result
    end
  end

  @spec fetch_struct(Keyword.t(), Keyword.key(), atom | [atom], struct()) ::
          {:ok, struct} | fetch_error
  def fetch_struct(keyword, key, struct, default = %{__struct__: struct})
      when is_list(keyword) and is_atom(key) and is_atom(struct) do
    with {:error, {_key, :not_found}} <- fetch_struct(keyword, key, struct) do
      {:ok, default}
    end
  end

  def fetch_struct(keyword, key, struct_list, default = %{__struct__: struct})
      when is_list(keyword) and is_atom(key) and is_list(struct_list) do
    true = Enum.member?(struct_list, struct)

    with {:error, {_key, :not_found}} <- fetch_struct(keyword, key, struct_list) do
      {:ok, default}
    end
  end

  @spec maybe_fetch_struct(Keyword.t(), Keyword.key(), atom | [atom], nil | struct) ::
          {:ok, struct | nil} | fetch_error
  def maybe_fetch_struct(_keyword, _key, _struct, default \\ nil)

  def maybe_fetch_struct(keyword, key, struct_or_struct_list, nil)
      when is_list(keyword) and is_atom(key) do
    case fetch_struct(keyword, key, struct_or_struct_list) do
      {:error, {_key, :not_found}} -> {:ok, nil}
      {:error, {_key, {:value, nil}}} -> {:ok, nil}
      result -> result
    end
  end

  def maybe_fetch_struct(keyword, key, struct, default = %{__struct__: struct})
      when is_list(keyword) and is_atom(key) and is_atom(struct) do
    case fetch_struct(keyword, key, struct) do
      {:error, {_key, :not_found}} -> {:ok, default}
      {:error, {_key, {:value, nil}}} -> {:ok, nil}
      result -> result
    end
  end

  def maybe_fetch_struct(keyword, key, struct_list, default = %{__struct__: struct})
      when is_list(keyword) and is_atom(key) and is_list(struct_list) do
    true = Enum.member?(struct_list, struct)

    case fetch_struct(keyword, key, struct_list) do
      {:error, {_key, :not_found}} -> {:ok, default}
      {:error, {_key, {:value, nil}}} -> {:ok, nil}
      result -> result
    end
  end
end
