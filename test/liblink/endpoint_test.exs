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

defmodule Liblink.EndpointTest do
  use ExUnit.Case, async: true

  alias Liblink.Endpoint

  test "host can be nil" do
    assert "tcp://0.0.0.0:4000" == Endpoint.tcp_endpoint(nil, 4000)
  end

  test "host can be a str" do
    assert "tcp://127.0.0.1:4000" == Endpoint.tcp_endpoint("127.0.0.1", 4000)
  end

  test "port can be nil" do
    assert "tcp://127.0.0.1:!" == Endpoint.tcp_endpoint("127.0.0.1", nil)
  end

  test "port can be a range" do
    assert "tcp://127.0.0.1:![1000-2000]" == Endpoint.tcp_endpoint("127.0.0.1", 1000..2000)
  end

  test "port can be :rnd" do
    assert Endpoint.tcp_endpoint("127.0.0.1", :rnd) == Endpoint.tcp_endpoint("127.0.0.1", nil)
  end
end
