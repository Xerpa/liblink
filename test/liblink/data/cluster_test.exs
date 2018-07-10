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

defmodule Liblink.Data.ClusterTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Cluster
  alias Liblink.Data.Cluster.Announce

  describe "new" do
    test "required fields" do
      assert {:error, {:id, :not_found}} == Cluster.new([])
      assert {:error, {{:announce, :discover}, :not_found}} == Cluster.new(id: "liblink")
    end

    test "validation" do
      assert {:error, {:id, {:value, :invalid}}} == Cluster.new(id: :invalid)

      assert {:error, {:announce, {:value, :invalid}}} ==
               Cluster.new(id: "liblink", announce: :invalid)

      assert {:error, {:discover, {:value, :invalid}}} ==
               Cluster.new(id: "liblink", discover: :invalid)

      assert {:error, {:policies, {:value, :invalid}}} ==
               Cluster.new(id: "liblink", policies: :invalid)
    end

    test "success case" do
      assert {:ok, %Cluster{}} = Cluster.new(id: "liblink", announce: %Announce{})
    end
  end
end
