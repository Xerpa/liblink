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

  @spec start_link([{:strategy, :one_for_one}], [{:name, atom}]) ::
          {:ok, pid} | {:error, {:already_started, pid}}
  def start_link(args, opts \\ [name: __MODULE__]) do
    DynamicSupervisor.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(args) do
    args = Keyword.put(args, :strategy, :one_for_one)

    DynamicSupervisor.init(args)
  end

  @spec start_child(Supervision.child_spec()) :: DynamicSupervisor.on_start_child()
  def start_child(child) do
    start_child(__MODULE__, child)
  end

  defdelegate start_child(pid, child), to: DynamicSupervisor
end
