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

defmodule Liblink.Cluster.NamingTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Liblink.Data.Cluster
  alias Liblink.Cluster.Naming

  property "request-response protocol is {cluster_id}-0" do
    check all cluster_id <- binary() do
      name = Naming.service_name(%Cluster{id: cluster_id}, :request_response)

      assert String.starts_with?(name, cluster_id)
      assert String.ends_with?(name, "-0")
    end
  end
end
