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

defmodule Liblink.Bench.Client do
  def init({parent, tag}, resource) do
    data = resource.acquire_fn.()
    send(parent, {tag, :pid, self()})
    send(parent, {tag, ioloop(resource, data)})

    receive do
      :term ->
        resource.release_fn.(data)
    end
  end

  def wait({_client, tag}) do
    receive do
      {^tag, message} -> message
    end
  end

  def ioloop(resource, data) do
    case resource.recvmsg_fn.(data, :infinity) do
      {"data", from, message} ->
        resource.sendmsg_fn.(data, "data", from, message)
        ioloop(resource, data)

      {"halt", from, message} ->
        resource.sendmsg_fn.(data, "halt", from, message)
        :done
    end
  end

  def spawn_task(nil, resource) do
    tag = :erlang.make_ref()
    spawn(__MODULE__, :init, [{self(), tag}, resource])

    receive do
      {^tag, :pid, pid} -> {:ok, {pid, tag}}
    end
  end

  def spawn_task(node, resource) do
    tag = :erlang.make_ref()
    Node.spawn(node, __MODULE__, :init, [{self(), tag}, resource])

    receive do
      {^tag, :pid, pid} -> {:ok, {pid, tag}}
    end
  end

  def close({client, _}) do
    send(client, :term)
  end
end
