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
  @moduledoc false

  @opaque socket :: binary

  defguardp is_message(iolist_or_binary)
            when is_binary(iolist_or_binary) or is_list(iolist_or_binary)

  defguardp is_socktype(x)
            when x == :router or x == :dealer

  defguardp is_endpoint(x)
            when is_binary(x)

  defguardp is_server(pid_or_atom)
            when is_pid(pid_or_atom) or is_atom(pid_or_atom)

  defguardp is_signal(signal)
            when signal == :cont or signal == :stop

  @doc false
  @spec load :: :ok | {:error, {atom, charlist}}
  def load do
    [:code.priv_dir(:liblink), "lib/liblink"]
    |> Path.join()
    |> String.to_charlist()
    |> :erlang.load_nif(0)
  end

  @doc false
  @spec new_socket(:router | :dealer, String.t(), String.t(), pid() | atom) ::
          {:ok, socket} | {:error, :badargs} | :error
  def new_socket(socktype, ext_endpoint, int_endpoint, server)
      when is_socktype(socktype) and is_endpoint(ext_endpoint) and is_endpoint(int_endpoint) and
             is_server(server),
      do: fail()

  @doc false
  @spec send(socket, iolist | binary) :: :ok | :error | {:error, :ioerror} | {:error, :badargs}
  def send(_socket, message) when is_message(message),
    do: fail()

  @doc false
  @spec signal(socket, :cont | :stop) :: :ok | :error | {:error, :badsignal} | {:error, :badargs}
  def signal(_socket, signal) when is_signal(signal), do: fail()

  @doc false
  @spec state(socket) :: :error | {:error, :badargs} | :quitting | :running | :waiting
  def state(_socket), do: fail()

  @doc false
  @spec term(socket) :: :ok | :error
  def term(_socket), do: fail()

  defp fail(), do: raise("nif function")
end
