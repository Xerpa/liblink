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

defmodule Liblink.Data.Keyword.Macros do
  defmacro def_fetch(name, guard) do
    fetch_name = String.to_atom("fetch_#{name}")
    maybe_fetch_name = String.to_atom("maybe_fetch_#{name}")

    quote do
      def unquote(fetch_name)(keyword, key) when is_list(keyword) and is_atom(key) do
        case fetch(keyword, key) do
          :error -> {:error, {key, :not_found}}
          {:ok, value} when unquote(guard)(value) -> {:ok, value}
          {:ok, value} -> {:error, {key, {:value, value}}}
        end
      end

      def unquote(fetch_name)(keyword, key, default)
          when is_list(keyword) and is_atom(key) and unquote(guard)(default) do
        with {:error, {_key, :not_found}} <- unquote(fetch_name)(keyword, key) do
          {:ok, default}
        end
      end

      def unquote(maybe_fetch_name)(keyword, key, default \\ nil)
          when is_list(keyword) and is_atom(key) and (unquote(guard)(default) or is_nil(default)) do
        case unquote(fetch_name)(keyword, key) do
          {:error, {_key, :not_found}} -> {:ok, default}
          {:error, {_key, {:value, nil}}} -> {:ok, nil}
          result -> result
        end
      end
    end
  end
end
