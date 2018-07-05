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

defmodule Liblink.Data.Consul.ServiceTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Consul.Service
  alias Liblink.Data.Consul.TTLCheck

  describe "to_consul" do
    test "convert a service to json" do
      service = %Service{
        id: "service-id",
        name: "service-name",
        tags: [:tag],
        meta: %{meta: "data"},
        addr: "127.0.0.1",
        port: 443,
        checks: [
          %TTLCheck{
            id: "check-id",
            name: "check-name",
            ttl: [{5, :m}],
            deregister_critical_service_after: [{90, :m}]
          }
        ]
      }

      assert %{
               "ID" => "service-id",
               "Name" => "service-name",
               "Port" => 443,
               "Address" => "127.0.0.1",
               "Tags" => ["tag"],
               "Meta" => %{
                 "meta" => "data"
               },
               "Checks" => [
                 %{
                   "CheckID" => "check-id",
                   "Name" => "check-name",
                   "DeregisterCriticalServiceAfter" => "90m",
                   "TTL" => "5m"
                 }
               ]
             } == Service.to_consul(service)
    end
  end
end
