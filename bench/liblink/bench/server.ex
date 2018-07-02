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

defmodule Liblink.Bench.Server do
  def ioloop(resource, data, message, 0) do
    resource.sendmsg_fn.(data, "halt", message)
    consume(resource, data, message, :infinity)
  end

  def ioloop(resource, data, message, snd_count) do
    resource.sendmsg_fn.(data, "data", message)
    consume(resource, data, message, 0)
    ioloop(resource, data, message, snd_count - 1)
  end

  def consume(resource, data, message, :infinity) do
    case resource.recvmsg_fn.(data, :infinity) do
      {"data", ^message} ->
        consume(resource, data, message, :infinity)

      {"halt", ^message} ->
        :done
    end
  end

  def consume(resource, data, message, timeout) do
    case resource.recvmsg_fn.(data, timeout) do
      {"data", ^message} ->
        consume(resource, data, message, timeout)

      {"halt", ^message} ->
        :done

      :timeout ->
        :timeout
    end
  end

  def init({parent, tag}, resource, message, iterations) do
    data = resource.acquire_fn.()

    send(parent, {tag, :pid, self()})

    receive do
      :start ->
        ans = ioloop(resource, data, message, iterations)
        send(parent, {tag, ans})

        receive do
          :term ->
            resource.release_fn.(data)
        end
    end
  end

  def run({pid, tag}) do
    send(pid, :start)

    receive do
      {^tag, :done} -> :done
    end
  end

  def close({server, _}) do
    send(server, :term)
  end

  def spawn_task(nil, resource, message, iterations) do
    tag = :erlang.make_ref()
    spawn(__MODULE__, :init, [{self(), tag}, resource, message, iterations])

    receive do
      {^tag, :pid, pid} -> {:ok, {pid, tag}}
    end
  end

  def spawn_task(node, resource, message, iterations) do
    tag = :erlang.make_ref()
    Node.spawn(node, __MODULE__, :init, [{self(), tag}, resource, message, iterations])

    receive do
      {^tag, :pid, pid} -> {:ok, {pid, tag}}
    end
  end
end
