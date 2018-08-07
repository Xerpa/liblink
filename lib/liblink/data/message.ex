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

defmodule Liblink.Data.Message do
  alias Liblink.Data.Codec

  import Liblink.Data.Macros

  @type t :: %__MODULE__{}

  defstruct [:metadata, :payload]

  @v0 <<0>>

  def new(payload, metadata \\ %{}) when is_map(metadata) do
    %__MODULE__{payload: payload, metadata: metadata_from_enum(metadata)}
  end

  def encode(message = %__MODULE__{}) do
    Codec.encode({@v0, message.metadata, message.payload})
  end

  def_bang(:decode, 1)

  def decode(message) do
    with {:ok, {@v0, metadata, payload}} when is_map(metadata) <- Codec.decode(message) do
      {:ok, %__MODULE__{metadata: metadata, payload: payload}}
    end
  end

  def meta_fetch(message = %__MODULE__{}, key) when is_binary(key) or is_atom(key) do
    key = String.downcase(to_string(key))
    Map.fetch(message.metadata, key)
  end

  def meta_get(message = %__MODULE__{}, key, default \\ nil)
      when is_binary(key) or is_atom(key) do
    key = String.downcase(to_string(key))
    Map.get(message.metadata, key, default)
  end

  def meta_put(message = %__MODULE__{}, key, value) when is_binary(key) or is_atom(key) do
    key = String.downcase(to_string(key))
    metadata = Map.put(message.metadata, key, value)
    %{message | metadata: metadata}
  end

  def meta_put_new(message = %__MODULE__{}, key, value) when is_binary(key) or is_atom(key) do
    key = String.downcase(to_string(key))
    metadata = Map.put_new(message.metadata, key, value)
    %{message | metadata: metadata}
  end

  def meta_merge(message = %__MODULE__{}, meta = %{}) do
    metadata = Map.merge(message.metadata, metadata_from_enum(meta))
    %{message | metadata: metadata}
  end

  defp metadata_from_enum(enum) do
    Map.new(enum, fn
      {k, v} when is_binary(k) ->
        {String.downcase(k), v}

      {k, v} when is_atom(k) ->
        {String.downcase(Atom.to_string(k)), v}
    end)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(message, opts) do
      concat([
        "#Message",
        to_doc([payload: message.payload, metadata: message.metadata], opts)
      ])
    end
  end
end
