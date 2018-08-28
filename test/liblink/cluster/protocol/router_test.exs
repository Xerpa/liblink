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
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Cluster.Protocol.Router
  alias Test.Liblink.TestService

  @moduletag capture_log: true

  describe "new" do
    test "valid cluster" do
      service =
        Service.new!(
          id: "foo",
          exports: Exports.new!(:module, module: TestService),
          protocol: :request_response
        )

      assert {:ok, _} = Router.new("liblink", [service])
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

      router = Router.new!("liblink", [service])

      {:ok, [router: router]}
    end

    test "application metadata", %{router: router} do
      reply_with = {:ok, Message.new(nil, %{foobar: :term})}
      reply = echo_request(router, {:echo, reply_with})

      assert %{"foobar" => :term} = reply.metadata
    end

    test "missing service", %{router: router} do
      assert {:error, :not_found, %Message{}} =
               request(Message.new(nil, %{"ll-service-id" => {"missing", :echo}}), router)
    end

    test "missing function", %{router: router} do
      assert {:error, :not_found, %Message{}} =
               request(Message.new(nil, %{"ll-service-id" => {"liblink", :missing}}), router)
    end

    test "service returning error", %{router: router} do
      reply_with = {:error, :some_error, Message.new(:payload)}
      assert {:error, :some_error, reply} = echo_request(router, {:echo, reply_with})
      assert :payload == reply.payload
    end

    test "service misbehaving", %{router: router} do
      reply_with = :misbehaving
      assert {:error, :bad_service, %Message{}} = echo_request(router, {:echo, reply_with})
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
    |> Message.meta_put_new("ll-service-id", {"liblink", :echo})
    |> request(router)
  end
end
