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

defmodule Liblink do
  use Application

  alias Liblink.Nif

  def start(_type, _args) do
    db_hooks = [
      Liblink.Cluster.Announce
    ]

    children = [
      %{
        id: Liblink.Socket.Monitor,
        start: {Liblink.Socket.Monitor, :start_link, [[], [name: Liblink.Socket.Monitor]]},
        restart: :permanent,
        shutdown: 30_000
      },
      %{
        id: Liblink.Cluster.ClusterSupervisor,
        start:
          {Liblink.Cluster.ClusterSupervisor, :start_link,
           [[], [name: Liblink.Cluster.ClusterSupervisor]]},
        restart: :permanent,
        shutdown: 30_000
      },
      %{
        id: Liblink.Cluster.Database,
        start:
          {Liblink.Cluster.Database, :start_link,
           [[hooks: db_hooks], [name: Liblink.Cluster.Database]]}
      }
    ]

    case Nif.load() do
      :ok -> Supervisor.start_link(children, strategy: :one_for_one)
      error -> {:error, {:load_nif, error}}
    end
  end
end
