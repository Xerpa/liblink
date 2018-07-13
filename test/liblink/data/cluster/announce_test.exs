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

defmodule Liblink.Data.Cluster.Exports.AnnounceTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Data.Cluster.Announce

  describe "new" do
    test "accepts atom/string metadata" do
      meta = %{
        :k0 => :bar,
        :k1 => "bar",
        "k2" => :bar,
        "k3" => "bar"
      }

      exports = Exports.new!(:module, module: __MODULE__)
      service = Service.new!(id: "foobar", protocol: :request_response, exports: exports)
      assert {:ok, announce} = Announce.new(services: [service], metadata: meta)
      assert meta == announce.metadata
    end

    test "requires at least one service" do
      assert {:error, {:services, :invalid}} = Announce.new(services: [])
    end

    test "services must be unique" do
      exports = Exports.new!(:module, module: __MODULE__)
      service = Service.new!(id: "foobar", protocol: :request_response, exports: exports)
      assert {:error, {:services, :invalid}} = Announce.new(services: [service, service])
    end

    test "success" do
      exports = Exports.new!(:module, module: __MODULE__)
      service = Service.new!(id: "foobar", protocol: :request_response, exports: exports)
      assert {:ok, announce} = Announce.new(services: [service])
      assert %{} == announce.metadata
      assert [service] == announce.services
    end
  end
end
