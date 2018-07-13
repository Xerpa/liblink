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

defmodule Liblink.Network.Consul.HealthTest do
  use ExUnit.Case, async: false

  alias Liblink.Network.Consul
  alias Liblink.Data.Consul.Check
  alias Liblink.Data.Consul.Config
  alias Liblink.Data.Consul.Service

  @moduletag consul: true

  setup do
    consul = Consul.client(Config.new!())

    check = Check.new!(:ttl, name: "service:liblink", id: "service:liblink")

    service =
      Service.new!(
        id: "liblink",
        name: "liblink",
        addr: "127.0.0.1",
        port: 4000,
        tags: ["tag"],
        meta: %{env: "prod"},
        checks: [check]
      )

    :ok = Test.Liblink.Consul.flush_services(consul)

    on_exit(fn ->
      {:ok, %{status: 200}} = Consul.Agent.service_deregister(consul, service.id)
    end)

    {:ok, [consul: consul, service: service, check: check]}
  end

  describe "service" do
    test "list all warning services", %{consul: consul, service: service, check: check} do
      {:ok, %{status: 200}} = Consul.Agent.service_register(consul, service)
      {:ok, %{status: 200}} = Consul.Agent.check_warn(consul, check.id)
      {:ok, reply} = Consul.Health.service(consul, service.name)

      data =
        reply.body
        |> List.first()
        |> Map.update("Checks", [], fn checks ->
          Enum.filter(checks, fn consul_check ->
            consul_check["CheckID"] == check.id
          end)
        end)

      check_id = check.id
      check_name = check.name
      service_id = service.id
      service_name = service.name

      assert 200 == reply.status
      assert 1 == Enum.count(reply.body)

      assert %{
               "Service" => %{
                 "ID" => ^service_id,
                 "Service" => ^service_name
               },
               "Checks" => [
                 %{
                   "CheckID" => ^check_id,
                   "Name" => ^check_name,
                   "ServiceID" => ^service_id,
                   "ServiceName" => ^service_name,
                   "Status" => "warning"
                 }
               ]
             } = data
    end

    test "list all failing services", %{consul: consul, service: service, check: check} do
      {:ok, %{status: 200}} = Consul.Agent.service_register(consul, service)
      {:ok, %{status: 200}} = Consul.Agent.check_fail(consul, check.id)
      {:ok, reply} = Consul.Health.service(consul, service.name)

      data =
        reply.body
        |> List.first()
        |> Map.update("Checks", [], fn checks ->
          Enum.filter(checks, fn consul_check ->
            consul_check["CheckID"] == check.id
          end)
        end)

      check_id = check.id
      check_name = check.name
      service_id = service.id
      service_name = service.name

      assert 200 == reply.status
      assert 1 == Enum.count(reply.body)

      assert %{
               "Service" => %{
                 "ID" => ^service_id,
                 "Service" => ^service_name
               },
               "Checks" => [
                 %{
                   "CheckID" => ^check_id,
                   "Name" => ^check_name,
                   "ServiceID" => ^service_id,
                   "ServiceName" => ^service_name,
                   "Status" => "critical"
                 }
               ]
             } = data
    end

    test "list all passing services", %{consul: consul, service: service, check: check} do
      {:ok, _} = Consul.Agent.service_register(consul, service)
      {:ok, _} = Consul.Agent.check_pass(consul, check.id)
      {:ok, reply} = Consul.Health.service(consul, service.name)

      data =
        reply.body
        |> List.first()
        |> Map.update("Checks", [], fn checks ->
          Enum.filter(checks, fn consul_check ->
            consul_check["CheckID"] == check.id
          end)
        end)

      check_id = check.id
      check_name = check.name
      service_id = service.id
      service_name = service.name

      assert 200 == reply.status
      assert 1 == Enum.count(reply.body)

      assert %{
               "Service" => %{
                 "ID" => ^service_id,
                 "Service" => ^service_name
               },
               "Checks" => [
                 %{
                   "CheckID" => ^check_id,
                   "Name" => ^check_name,
                   "ServiceID" => ^service_id,
                   "ServiceName" => ^service_name,
                   "Status" => "passing"
                 }
               ]
             } = data
    end
  end
end
