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

defmodule Liblink.Cluster.Naming do
  alias Liblink.Data.Cluster

  @spec protocol_code(Liblink.Data.Cluster.Service.protocol()) :: String.t()
  defp protocol_code(protocol) do
    case protocol do
      :request_response -> "0"
    end
  end

  @spec service_name(Cluster.t(), Liblink.Data.Cluster.Service.protocol()) :: String.t()
  def service_name(cluster = %Cluster{}, protocol) do
    cluster.id <> "-" <> protocol_code(protocol)
  end
end
