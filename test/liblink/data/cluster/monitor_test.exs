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

defmodule Liblink.Data.Cluster.MonitorTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Cluster.Monitor

  describe "new" do
    test "default" do
      assert %Monitor{interval_in_ms: 1_000, monitor: monitor} = Monitor.new!()
      assert monitor.()
    end

    test "success" do
      monitor = fn -> false end

      assert %Monitor{interval_in_ms: 1, monitor: monitor} ==
               Monitor.new!(interval_in_ms: 1, monitor: monitor)
    end
  end
end
