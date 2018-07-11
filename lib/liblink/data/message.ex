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
    true = Enum.all?(metadata, fn {k, _} -> is_atom(k) or is_binary(k) end)
    %__MODULE__{payload: payload, metadata: metadata}
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

  def meta_fetch(message = %__MODULE__{}, header) when is_atom(header) or is_binary(header) do
    Map.fetch(message.metadata, header)
  end

  def meta_get(message = %__MODULE__{}, header, default \\ nil)
      when is_atom(header) or is_binary(header) do
    Map.get(message.metadata, header, default)
  end

  def meta_put(message = %__MODULE__{}, key, value) when is_binary(key) or is_atom(key) do
    metadata = Map.put(message.metadata, key, value)
    %{message | metadata: metadata}
  end

  def meta_put_new(message = %__MODULE__{}, key, value) when is_binary(key) or is_atom(key) do
    metadata = Map.put_new(message.metadata, key, value)
    %{message | metadata: metadata}
  end
end
