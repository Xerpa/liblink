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

  alias Liblink.Data.Codec
  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Service
  alias Liblink.Data.Cluster.Exports
  alias Liblink.Data.Cluster.Announce
  alias Liblink.Cluster.Protocol.Router

  @moduletag capture_log: true

  describe "new" do
    test "cluster with duplicated services" do
      service =
        Service.new!(
          id: "foo",
          protocol: :request_response,
          exports: Exports.new!(:module, module: __MODULE__)
        )

      cluster = Cluster.new!(id: "liblink", announce: Announce.new!(services: [service, service]))

      assert :error == Router.new(cluster)
    end

    test "valid cluster" do
      service =
        Service.new!(
          id: "foo",
          exports: Exports.new!(:module, module: __MODULE__),
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
          exports:
            Exports.new!(
              :module,
              module: __MODULE__
            ),
          protocol: :request_response
        )

      announce = Announce.new!(services: [service])

      cluster = Cluster.new!(id: "liblink", announce: announce)

      router = Router.new!(cluster)

      {:ok, [router: router]}
    end

    test "response includes date/status header", %{router: router} do
      now = DateTime.utc_now()
      {meta, _payload} = echo_request(router, %{}, :payload)

      assert {:ok, :success} = Map.fetch(meta, :status)
      assert {:ok, date} = Map.fetch(meta, :date)
      assert 1 >= DateTime.diff(now, date, :seconds)
    end

    test "application metadata", %{router: router} do
      {meta, payload} = echo_request(router, %{foobar: true}, :payload)

      assert :payload == payload

      assert %{
               :status => :success,
               "foobar" => true
             } = meta
    end

    test "missing service", %{router: router} do
      {meta, payload} = echo_request(router, %{}, :payload, service_id: "missing")

      assert {:error, {:not_found, :service}} == payload
      assert %{status: :failure} = meta
    end

    test "missing function", %{router: router} do
      {meta, payload} = echo_request(router, %{}, :payload, function: :missing)

      assert {:error, {:not_found, :service}} == payload
      assert %{status: :failure} = meta
    end

    test "invalid arguments", %{router: router} do
      {meta, payload} = echo_request(router, :not_a_map, :payload)

      assert {:error, {:except, %FunctionClauseError{}, _stacktrace}} = payload
      assert %{status: :failure} = meta
    end

    test "service returning error", %{router: router} do
      {meta, payload} = echo_request(router, %{}, {:error, :payload}, return: :error)

      assert {:error, :payload} == payload
      assert %{status: :failure} = meta
    end

    test "service misbehaving", %{router: router} do
      {meta, payload} = echo_request(router, %{}, :payload, return: :bad_return)

      assert {:error, :bad_service} == payload
      assert %{status: :failure} = meta
    end
  end

  defp echo_request(router, request_meta, request_payload, opts \\ []) do
    function = Keyword.get(opts, :function, :echo)
    meta = %{service_id: Keyword.get(opts, :service_id, "liblink")}
    return = Keyword.get(opts, :return, :ok)

    [peer | [msgid | reply]] =
      Router.dispatch(
        [
          "peer"
          | ["msgid" | Codec.encode(meta, {function, {return, request_meta, request_payload}})]
        ],
        router
      )

    assert "peer" == peer
    assert "msgid" == msgid
    Codec.decode!(reply)
  end

  def echo(_req_meta, {atom, meta, payload}) when is_atom(atom) and is_map(meta) do
    {atom, meta, payload}
  end
end
