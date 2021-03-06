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

defmodule Liblink.Logger do
  require Logger

  defmacro __using__(_arg) do
    quote do
      require Liblink.Logger
      require Logger
    end
  end

  @spec log(
          %{src: String.t(), fun: String.t()},
          :debug | :info | :warn | :error,
          String.t() | (() -> String.t())
        ) :: nil
  def log(env, level, message)
      when is_atom(level) and (is_binary(message) or is_function(message, 0)) do
    backend = Application.get_env(:liblink, :logger, &Logger.log/2)

    if backend do
      apply(backend, [
        level,
        fn ->
          message =
            if is_function(message, 0) do
              message.()
            else
              message
            end

          Enum.join(["[liblink][#{env.fun}] #{env.src}", message], "\n")
        end
      ])
    end

    nil
  end

  defmacro debug(message) do
    env = Macro.escape(getenv(__CALLER__))

    quote do
      Liblink.Logger.log(unquote(env), :debug, unquote(message))
    end
  end

  defmacro info(message) do
    env = Macro.escape(getenv(__CALLER__))

    quote do
      Liblink.Logger.log(unquote(env), :info, unquote(message))
    end
  end

  defmacro warn(message) do
    env = Macro.escape(getenv(__CALLER__))

    quote do
      Liblink.Logger.log(unquote(env), :warn, unquote(message))
    end
  end

  defmacro error(message) do
    env = Macro.escape(getenv(__CALLER__))

    quote do
      Liblink.Logger.log(unquote(env), :error, unquote(message))
    end
  end

  defp getenv(env) do
    %{
      src: Enum.join([env.file, env.line], ":"),
      fun:
        case env.function do
          {fun, ari} -> Enum.join([env.module, Enum.join([fun, ari], "/")], ".")
          nil -> Atom.to_string(env.module)
        end
    }
  end
end
