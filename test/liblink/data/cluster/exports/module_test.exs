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

defmodule Liblink.Data.Cluster.Exports.ModuleTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Cluster.Exports.Module

  describe "new" do
    test "module attribute" do
      {:ok, module} = Module.new(module: __MODULE__)

      assert __MODULE__ == module.module
    end

    test "without only/except restriction" do
      {:ok, module} = Module.new(module: __MODULE__)

      assert module.restriction.(:foo)
      refute module.restriction.("term")
    end

    test "only restriction is whitelist" do
      {:ok, module} = Module.new(module: __MODULE__, only: [:foo])

      assert module.restriction.(:foo)
      refute module.restriction.(:wat)
    end

    test "except restriction is blacklist" do
      {:ok, module} = Module.new(module: __MODULE__, except: [:wat])

      assert module.restriction.(:foo)
      refute module.restriction.(:wat)
    end

    test "except has higher priority than accept" do
      {:ok, module} = Module.new(module: __MODULE__, only: [:foo, :wat], except: [:wat])

      assert module.restriction.(:foo)
      refute module.restriction.(:wat)
    end
  end

  # XXX: for testing
  def foo(_payload), do: nil
end
