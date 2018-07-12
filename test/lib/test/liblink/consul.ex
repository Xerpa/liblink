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

defmodule Test.Liblink.Consul do
  alias Liblink.Data.Consul.Config
  alias Liblink.Network.Consul

  def flush_services do
    Config.new!()
    |> Consul.client()
    |> flush_services()
  end

  def flush_services(consul) do
    {:ok, reply} = Consul.Agent.services(consul)

    Enum.each(reply.body, fn {service_id, _} ->
      {:ok, %{status: 200}} = Consul.Agent.service_deregister(consul, service_id)
    end)
  end
end
