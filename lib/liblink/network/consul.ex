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

defmodule Liblink.Network.Consul do
  alias Liblink.Data.Consul.Config

  defstruct [:agent, :config]

  @type t :: %__MODULE__{}

  @spec client(Config.t()) :: t
  def client(config = %Config{}) do
    middleware = [
      {Tesla.Middleware.BaseUrl, config.endpoint},
      {Tesla.Middleware.Timeout, timeout: config.timeout},
      {Tesla.Middleware.Headers, [{"x-consul-token", config.token}]},
      {Tesla.Middleware.JSON, []}
    ]

    adapter = Application.get_env(:liblink, :tesla)[:adapter]

    client = Tesla.client(middleware, adapter)

    %__MODULE__{agent: client, config: config}
  end
end
