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

defmodule Liblink.Socket.Device do
  alias Liblink.Nif

  @type t :: %__MODULE__{
          socket: Nif.socket_t(),
          sendmsg_pid: pid,
          recvmsg_pid: pid
        }

  defstruct [:socket, :sendmsg_pid, :recvmsg_pid]

  def new(socket, recvmsg, sendmsg) do
    device = %__MODULE__{socket: socket, sendmsg_pid: sendmsg, recvmsg_pid: recvmsg}

    with :ok <- GenServer.call(sendmsg, {:attach, device}),
         :ok <- GenServer.call(recvmsg, {:attach, device}) do
      {:ok, device}
    end
  end

  def bind_port(device = %__MODULE__{}) do
    Nif.bind_port(device.socket)
  end
end
