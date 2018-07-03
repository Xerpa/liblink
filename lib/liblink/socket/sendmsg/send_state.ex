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

defmodule Liblink.Socket.Sendmsg.SendState do
  use Liblink.Socket.Sendmsg.Fsm

  alias Liblink.Nif

  @impl true
  def sendmsg(iodata, data) do
    {:cont, Nif.sendmsg(data.device.socket, iodata), {__MODULE__, data}}
  end

  @impl true
  def sendmsg(iodata, deadline, data) do
    timenow = :erlang.monotonic_time()

    reply =
      if timenow > deadline do
        {:error, :timeout}
      else
        Nif.sendmsg(data.device.socket, iodata)
      end

    {:cont, reply, {__MODULE__, data}}
  end
end
