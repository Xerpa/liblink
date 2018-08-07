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

defmodule Liblink.CfgTest do
  use ExUnit.Case, async: true

  alias Liblink.Cfg

  setup do
    backup = Application.get_env(:liblink, :netcfg)

    on_exit(fn ->
      if backup do
        Application.put_env(:liblink, :netcfg, backup)
      else
        Application.delete_env(:liblink, :netcfg)
      end
    end)
  end

  describe "protocol_host" do
    test "returns nil if there is no cfg or cfg is invalid" do
      assert is_nil(Cfg.protocol_host(:request_response))

      Application.put_env(:liblink, :netcfg, request_response: :no_list)
      assert is_nil(Cfg.protocol_host(:request_response))

      Application.put_env(:liblink, :netcfg, request_response: [host: :invalid])
      assert is_nil(Cfg.protocol_host(:request_response))
    end

    test "use the configuration" do
      Application.put_env(:liblink, :netcfg, request_response: [host: "127.0.0.1"])
      assert "127.0.0.1" == Cfg.protocol_host(:request_response)
    end
  end

  describe "protocol_port" do
    test "returns nil if there is no cfg or cfg is invalid" do
      assert is_nil(Cfg.protocol_port(:request_response))

      Application.put_env(:liblink, :netcfg, request_response: :no_list)
      assert is_nil(Cfg.protocol_port(:request_response))

      Application.put_env(:liblink, :netcfg, request_response: [port: :invalid])
      assert is_nil(Cfg.protocol_port(:request_response))
    end

    test "use configuration | integer" do
      Application.put_env(:liblink, :netcfg, request_response: [port: 10])
      assert 10 == Cfg.protocol_port(:request_response)
    end

    test "use configuration | range" do
      Application.put_env(:liblink, :netcfg, request_response: [port: 10..100])
      assert 10..100 == Cfg.protocol_port(:request_response)
    end
  end
end
