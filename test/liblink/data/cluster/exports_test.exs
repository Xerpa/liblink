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

defmodule Liblink.Data.Cluster.Exports.ExportsTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Cluster.Exports
  alias Liblink.Data.Cluster.Exports.Module

  describe "new" do
    test "new :module" do
      module = Module.new!(module: __MODULE__)
      assert {:ok, module} == Exports.new(:module, module: __MODULE__)
    end
  end
end
