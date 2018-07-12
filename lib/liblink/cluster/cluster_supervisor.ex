# Copyright (C) 2018  Xerpa

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Liblink.Cluster.ClusterSupervisor do
  use DynamicSupervisor

  alias Liblink.Data.Keyword

  def start_link(args, opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(args) do
    args = Keyword.put(args, :strategy, :one_for_one)

    DynamicSupervisor.init(args)
  end

  def start_child(pid \\ __MODULE__, child) do
    DynamicSupervisor.start_child(pid, child)
  end

  def terminate_child(pid \\ __MODULE__, child_pid) do
    DynamicSupervisor.terminate_child(pid, child_pid)
  end
end
