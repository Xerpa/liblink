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

defmodule Liblink.Data.Cluster.DiscoverTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Liblink.Data.Cluster.Discover

  describe "new/0" do
    property "default discover accept all metadata" do
      discover = Discover.new!(protocols: [:request_response])

      check all metadata <- map_of(binary(), binary()) do
        assert discover.restrict.(metadata)
      end
    end
  end

  describe "new/1" do
    test "validate arguments" do
      restrict = fn -> nil end

      assert {:error, {:protocols, :not_found}} == Discover.new()
      assert {:error, {:protocols, {:value, :foobar}}} == Discover.new(protocols: :foobar)

      assert {:error, {:restrict, {:value, :foobar}}} ==
               Discover.new(restrict: :foobar, protocols: [:request_response])

      assert {:error, {:restrict, {:value, restrict}}} ==
               Discover.new(restrict: restrict, protocols: [:request_response])
    end
  end
end
