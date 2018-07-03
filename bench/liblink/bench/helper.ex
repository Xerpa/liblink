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

defmodule Liblink.Bench.Helper do
  alias Liblink.Nif

  import Liblink.Random

  def otp_client() do
    %{
      acquire_fn: fn -> nil end,
      release_fn: fn _ -> nil end,
      recvmsg_fn: fn _, timeout ->
        receive do
          {code, from, message} -> {code, from, message}
        after
          timeout -> :timeout
        end
      end,
      sendmsg_fn: fn _, code, from, message ->
        send(from, {code, message})
      end
    }
  end

  def nif_client(endpoint) do
    %{
      acquire_fn: fn ->
        {:ok, nif} = Nif.new_socket(:router, "@" <> endpoint, random_inproc_endpoint(), self())

        nif
      end,
      release_fn: fn nif -> Nif.term(nif) end,
      recvmsg_fn: fn _, timeout ->
        receive do
          {:liblink_message, [message, code, from]} ->
            {code, from, message}
        after
          timeout -> :timeout
        end
      end,
      sendmsg_fn: fn nif, code, from, message ->
        Nif.sendmsg(nif, [from, code, message])
      end
    }
  end

  def nif_server(endpoint) do
    %{
      acquire_fn: fn ->
        {:ok, nif} = Nif.new_socket(:dealer, ">" <> endpoint, random_inproc_endpoint(), self())

        nif
      end,
      release_fn: fn nif -> Nif.term(nif) end,
      recvmsg_fn: fn _nif, timeout ->
        receive do
          {:liblink_message, [message, code]} -> {code, message}
        after
          timeout -> :timeout
        end
      end,
      sendmsg_fn: fn nif, code, message ->
        Nif.sendmsg(nif, [code, message])
      end
    }
  end

  def otp_server({client, _}) do
    %{
      acquire_fn: fn -> self() end,
      release_fn: fn _ -> nil end,
      sendmsg_fn: fn self, code, message ->
        send(client, {code, self, message})
      end,
      recvmsg_fn: fn _, timeout ->
        receive do
          {code, message} -> {code, message}
        after
          timeout -> :timeout
        end
      end
    }
  end
end
