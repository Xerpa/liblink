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

defmodule Liblink.Data.Cluster.ServiceTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Data.Cluster.Monitor

  describe "new" do
    test "new service" do
      exports = Exports.new!(:module, module: __MODULE__)
      monitor = Monitor.new!()

      assert {:ok, service} =
               Service.new(
                 id: "service-id",
                 protocol: :request_response,
                 exports: exports,
                 monitor: monitor
               )

      assert :request_response == service.protocol
      assert "service-id" == service.id
      assert exports == service.exports
      assert monitor == service.monitor
    end
  end
end
