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

defmodule Liblink.Cluster.Protocol.RouterTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Message
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Cluster.Protocol.Router
  alias Test.Liblink.TestService

  @moduletag capture_log: true

  describe "new" do
    test "cluster with duplicated services" do
      service =
        Service.new!(
          id: "foo",
          protocol: :request_response,
          exports: Exports.new!(:module, module: TestService)
        )

      cluster = Cluster.new!(id: "liblink", announce: Announce.new!(services: [service, service]))

      assert :error == Router.new(cluster)
    end

    test "valid cluster" do
      service =
        Service.new!(
          id: "foo",
          exports: Exports.new!(:module, module: TestService),
          protocol: :request_response
        )

      cluster = Cluster.new!(id: "liblink", announce: Announce.new!(services: [service]))

      assert {:ok, _} = Router.new(cluster)
    end
  end

  describe "dispatch" do
    setup do
      service =
        Service.new!(
          id: "liblink",
          exports: Exports.new!(:module, module: TestService),
          protocol: :request_response
        )

      announce = Announce.new!(services: [service])

      cluster = Cluster.new!(id: "liblink", announce: announce)

      router = Router.new!(cluster)

      {:ok, [router: router]}
    end

    test "response includes date/status header", %{router: router} do
      now = DateTime.utc_now()
      reply = ping_request(router)

      assert {:ok, :success} = Message.meta_fetch(reply, :status)
      assert {:ok, date} = Message.meta_fetch(reply, :date)
      assert 1 >= DateTime.diff(now, date, :seconds)
    end

    test "application metadata", %{router: router} do
      reply_with = {:ok, Message.new(nil, %{foobar: :term})}
      reply = echo_request(router, {:echo, reply_with})

      assert %{
               :status => :success,
               "foobar" => :term
             } = reply.metadata
    end

    test "missing service", %{router: router} do
      reply = request(Message.new(nil, %{service_id: {"missing", :echo}}), router)

      assert {:error, :not_found} == reply.payload
      assert %{status: :failure} = reply.metadata
    end

    test "missing function", %{router: router} do
      reply = request(Message.new(nil, %{service_id: {"liblink", :missing}}), router)

      assert {:error, :not_found} == reply.payload
      assert %{status: :failure} = reply.metadata
    end

    test "service returning error", %{router: router} do
      reply_with = {:error, Message.new(:payload)}
      reply = echo_request(router, {:echo, reply_with})

      assert :payload == reply.payload
      assert %{status: :failure} = reply.metadata
    end

    test "service misbehaving", %{router: router} do
      reply_with = :bad_return
      reply = echo_request(router, {:echo, reply_with})

      assert {:error, :bad_service} == reply.payload
      assert %{status: :failure} = reply.metadata
    end
  end

  defp request(request, router) do
    ["peer" | ["msgid" | reply]] =
      Router.dispatch(["peer" | ["msgid" | Message.encode(request)]], router)

    Message.decode!(reply)
  end

  defp echo_request(router, payload) do
    payload
    |> Message.new()
    |> Message.meta_put_new(:service_id, {"liblink", :echo})
    |> request(router)
  end

  defp ping_request(router) do
    Message.new(:ping)
    |> Message.meta_put_new(:service_id, {"liblink", :ping})
    |> request(router)
  end
end
