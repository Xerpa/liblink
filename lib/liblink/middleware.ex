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

defmodule Liblink.Middleware do
  alias Liblink.Data.Message

  @type continue :: (Message.t() -> {:ok, Message.t()} | {:error, atom} | {:error, atom, term})

  @callback call(Message.t(), term, continue) ::
              {:ok, Message.t()} | {:error, atom} | {:error, atom, term}

  defmacro __using__(_args) do
    quote do
      @behaviour Liblink.Middleware
      @before_compile Liblink.Middleware

      import Liblink.Middleware, only: [middleware: 1, middleware: 2]

      Module.register_attribute(__MODULE__, :middlewares, accumulate: true, persist: false)
    end
  end

  defmacro middleware(module0, options \\ []) do
    if [] != Keyword.drop(options, [:data, :only, :except]) do
      keys =
        options
        |> Keyword.keys()
        |> Enum.join(",")

      raise(RuntimeError, message: "unsupported options: #{keys}")
    end

    data = Keyword.get(options, :data, nil)
    only = Keyword.get(options, :only, [])
    except = Keyword.get(options, :except, [])

    quote do
      module =
        case unquote(module0) do
          :logger -> Liblink.Middleware.Logger
          :except -> Liblink.Middleware.Except
          module -> module
        end

      @middlewares {module, unquote(data), MapSet.new(unquote(only)), MapSet.new(unquote(except))}
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __advise__(function, message) when is_atom(function) do
        middlewares =
          Enum.reduce(@middlewares, [], fn {middleware, data, only, except}, middlewares ->
            use_middleware? =
              (Enum.empty?(only) or MapSet.member?(only, function)) and
                not MapSet.member?(except, function)

            if use_middleware? do
              [{middleware, data} | middlewares]
            else
              middlewares
            end
          end)

        Liblink.Middleware.advise_function(
          Enum.reverse(middlewares),
          {__MODULE__, function},
          message
        )
      end
    end
  end

  @spec advise_ext(module, atom, Message.t()) ::
          {:ok, Message.t()} | {:error, atom} | {:error, atom, Message.t()}
  def advise_ext(mod, fun, message) do
    middlewares = [{Liblink.Middleware.Logger, nil}, {Liblink.Middleware.Except, nil}]
    advise_function(middlewares, {mod, fun}, message)
  end

  @spec advise_function([{module, term}], {module, atom}, Message.t()) ::
          {:ok, Message.t()} | {:error, atom} | {:error, atom, Message.t()}
  def advise_function([], {mod, fun}, message) do
    if function_exported?(mod, fun, 1) do
      case apply(mod, fun, [message]) do
        term = {:ok, %Message{}} ->
          term

        term = {:error, error} when is_atom(error) ->
          term

        term = {:error, error, %Message{}} when is_atom(error) ->
          term

        _term ->
          {:error, :bad_service}
      end
    else
      {:error, :not_found}
    end
  end

  def advise_function([{mod, data} | mod_rest], function, message) do
    continue = fn message -> advise_function(mod_rest, function, message) end
    apply(mod, :call, [message, data, continue])
  end
end
