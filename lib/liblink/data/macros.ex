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

defmodule Liblink.Data.Macros do
  defmacro def_bang(fn_name, arity) when is_atom(fn_name) do
    fn_bang =
      fn_name
      |> Atom.to_string()
      |> Kernel.<>("!")
      |> String.to_atom()

    fn_argv =
      0..arity
      |> Enum.drop(1)
      |> Enum.map(fn i ->
        var = String.to_atom("arg_" <> to_string(i))
        Macro.var(var, __MODULE__)
      end)

    quote do
      def unquote(fn_bang)(unquote_splicing(fn_argv)) do
        {:ok, ans} = unquote(fn_name)(unquote_splicing(fn_argv))
        ans
      end
    end
  end
end
