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

defmodule Liblink.Socket.Shared do
  @spec halt(pid, integer | :infinity) :: :ok
  def halt(pid, timeout) do
    tag = Process.monitor(pid)
    GenServer.cast(pid, :halt)

    receive do
      {:DOWN, ^tag, :process, _pid, _reason} ->
        Process.demonitor(tag)
        :ok
    after
      timeout ->
        Process.demonitor(tag)
        Process.exit(pid, :kill)
        :ok
    end
  end
end
