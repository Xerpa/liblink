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
    monitor = Supervisor.child_spec(Liblink.Socket.Monitor, shutdown: 10_000)

    db_hooks = [
      Liblink.Cluster.Announce,
      Liblink.Cluster.Discover,
      Liblink.Cluster.Discover.ClientDevice,
      Liblink.Cluster.Discover.Client,
      Liblink.Cluster.Discover.Device
    ]

    database = Liblink.Cluster.Database.child_spec(hooks: db_hooks)
    cluster_supervisor = Supervisor.child_spec({Liblink.Cluster.ClusterSupervisor, []}, [])

    children = [
      monitor,
      database,
      cluster_supervisor
    ]

    case Nif.load() do
      :ok -> Supervisor.start_link(children, strategy: :one_for_one)
      error -> {:error, {:load_nif, error}}
    end
  end
end
