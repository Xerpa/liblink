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

defmodule Liblink.Network.Consul.AgentTest do
  use ExUnit.Case, async: false

  alias Liblink.Network.Consul
  alias Liblink.Data.Consul.Config
  alias Liblink.Data.Consul.Check
  alias Liblink.Data.Consul.Service

  @moduletag consul: true

  setup do
    consul = Consul.client(Config.new!())

    check =
      Check.new!(
        :ttl,
        id: "check-liblink-id",
        name: "check-liblink"
      )

    service =
      Service.new!(
        id: "svcs-liblink-id",
        name: "svc-liblink",
        addr: "127.0.0.1",
        port: 4000,
        tags: ["tag"],
        meta: %{"env" => "prod"},
        checks: [check]
      )

    on_exit(fn ->
      {:ok, %{status: 200}} = Consul.Agent.service_deregister(consul, service.id)
    end)

    {:ok, [consul: consul, service: service, check: check]}
  end

  describe "services" do
    test "initial state", %{consul: consul, service: service} do
      assert {:ok, reply} = Consul.Agent.service(consul, service.name)
      assert 200 == reply.status
      assert %{} == reply.body
    end

    test "services after deregistration", %{consul: consul, service: service} do
      assert {:ok, %{status: 200}} = Consul.Agent.service_register(consul, service)
      assert {:ok, %{status: 200}} = Consul.Agent.service_deregister(consul, service.id)
      assert {:ok, reply} = Consul.Agent.service(consul, service.name)

      assert 200 == reply.status
      assert %{} == reply.body
    end

    test "services after registration", %{consul: consul, service: service} do
      service_id = service.id
      service_name = service.name
      service_port = service.port
      service_addr = service.addr
      service_tags = service.tags
      service_meta = service.meta

      assert {:ok, %{status: 200}} = Consul.Agent.service_register(consul, service)
      assert {:ok, reply} = Consul.Agent.service(consul, service.id)

      assert 200 == reply.status

      assert %{
               ^service_id => %{
                 "ID" => ^service_id,
                 "Service" => ^service_name,
                 "Address" => ^service_addr,
                 "Port" => ^service_port,
                 "Tags" => ^service_tags,
                 "Meta" => ^service_meta
               }
             } = reply.body
    end
  end

  describe "checks" do
    test "return all registered checks", %{consul: consul, service: service, check: check} do
      service_id = service.id
      service_name = service.name
      check_id = check.id
      check_name = check.name
      check_status = to_string(check.status)

      {:ok, %{status: 200}} = Consul.Agent.service_register(consul, service)
      {:ok, reply = %{status: 200}} = Consul.Agent.check(consul, check.id)

      assert %{
               ^check_id => %{
                 "CheckID" => ^check_id,
                 "Name" => ^check_name,
                 "Status" => ^check_status,
                 "ServiceID" => ^service_id,
                 "ServiceName" => ^service_name
               }
             } = reply.body
    end

    test "check is passing after check_pass", %{consul: consul, service: service, check: check} do
      check_id = check.id

      {:ok, %{status: 200}} = Consul.Agent.service_register(consul, service)
      {:ok, %{status: 200}} = Consul.Agent.check_pass(consul, check.id)
      {:ok, reply = %{status: 200}} = Consul.Agent.check(consul, check.id)

      assert %{^check_id => %{"Status" => "passing"}} = reply.body
    end

    test "check is critical after check_fail", %{consul: consul, service: service, check: check} do
      check_id = check.id

      {:ok, %{status: 200}} = Consul.Agent.service_register(consul, service)
      {:ok, %{status: 200}} = Consul.Agent.check_fail(consul, check.id)
      {:ok, reply = %{status: 200}} = Consul.Agent.check(consul, check.id)

      assert %{^check_id => %{"Status" => "critical"}} = reply.body
    end

    test "check is warning after check_fail", %{consul: consul, service: service, check: check} do
      check_id = check.id

      {:ok, %{status: 200}} = Consul.Agent.service_register(consul, service)
      {:ok, %{status: 200}} = Consul.Agent.check_warn(consul, check.id)
      {:ok, reply = %{status: 200}} = Consul.Agent.check(consul, check.id)

      assert %{^check_id => %{"Status" => "warning"}} = reply.body
    end

    test "check is gone is service is unregistered", %{
      consul: consul,
      service: service,
      check: check
    } do
      check_id = check.id

      {:ok, %{status: 200}} = Consul.Agent.service_register(consul, service)
      {:ok, r_before = %{status: 200}} = Consul.Agent.check(consul, check.id)
      {:ok, %{status: 200}} = Consul.Agent.service_deregister(consul, service.id)
      {:ok, r_after = %{status: 200}} = Consul.Agent.check(consul, check.id)

      assert %{^check_id => _} = r_before.body
      assert %{} == r_after.body
    end
  end
end
