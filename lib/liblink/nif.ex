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

defmodule Liblink.Nif do
  import Liblink.Guards

  @dialyzer [:unknown]
  @moduledoc false

  @opaque socket_t :: reference

  @type socket_type :: :router | :dealer

  @type signal_return :: :ok | :error | {:error, :badsignal} | {:error, :badargs}

  @type sendmsg_return :: :ok | :error | {:error, :ioerror} | {:error, :badargs}

  @type state_return :: :error | {:error, :badargs} | :quitting | :running | :waiting

  @type term_return :: :ok | :error

  @type new_socket_return :: {:ok, socket_t} | :error | {:error, :badargs}

  @doc false
  @spec load :: :ok | {:error, {atom, charlist}}
  def load do
    [:code.priv_dir(:liblink), "lib/liblink"]
    |> Path.join()
    |> String.to_charlist()
    |> :erlang.load_nif(0)
    |> case do
      :ok -> :ok
      {:error, {:reload, _}} -> :ok
      error -> error
    end
  end

  @doc false
  @spec new_socket(socket_type, String.t(), String.t(), pid()) :: new_socket_return
  def new_socket(socktype, ext_endpoint, int_endpoint, server)
      when is_socket_type(socktype) and is_binary(ext_endpoint) and is_binary(int_endpoint) and
             is_pid(server),
      do: fail()

  @doc false
  @spec bind_port(socket_t) :: integer() | nil | {:error, :badargs}
  def bind_port(socket) when is_reference(socket), do: fail()

  @doc false
  @spec sendmsg(socket_t, iodata) :: sendmsg_return
  def sendmsg(socket, message) when is_reference(socket) and is_iodata(message),
    do: fail()

  @doc false
  @spec signal(socket_t, :cont | :stop) :: signal_return
  def signal(socket, signal) when is_reference(socket) and is_signal(signal), do: fail()

  @doc false
  @spec state(socket_t) :: state_return
  def state(socket) when is_reference(socket), do: fail()

  @doc false
  @spec term(socket_t) :: term_return
  def term(socket) when is_reference(socket), do: fail()

  @spec fail() :: any
  defp fail(), do: Liblink.Hidden.fail("nif function")
end
