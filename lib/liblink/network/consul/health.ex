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

defmodule Liblink.Network.Consul.Health do
  @type option ::
          {:dc, String.t()}
          | {:near, String.t()}
          | {:service, String.t()}
          | {:node_meta, String.t()}

  @spec service(Tesla.Client.t(), String.t(), [option]) :: Tesla.Env.result()
  def service(client = %Tesla.Client{}, service, params \\ []) do
    params =
      Enum.map(params, fn {key, value} ->
        if key == :node_meta do
          {"node-meta", value}
        else
          {to_string(key), value}
        end
      end)

    Tesla.get(client, "/v1/health/service/#{service}", query: params)
  end
end
