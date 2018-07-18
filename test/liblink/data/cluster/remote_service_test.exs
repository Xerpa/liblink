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

defmodule Liblink.Data.Cluster.RemoteServiceTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.RemoteService

  describe "new" do
    test "optional params" do
      options = [
        cluster: %Cluster{},
        address: "addr",
        port: 7031,
        status: :passing,
        protocol: :request_response
      ]

      assert {:ok, service} = RemoteService.new(options)
      assert [] == service.tags
      assert %{} == service.metadata
    end
  end

  describe "connect_endpoint" do
    test "request_response protocol" do
      options = [
        cluster: %Cluster{},
        address: "addr",
        port: 7031,
        status: :passing,
        protocol: :request_response
      ]

      service = RemoteService.new!(options)
      assert ">tcp://addr:7031" == service.connect_endpoint
    end
  end
end
