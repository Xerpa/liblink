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

defmodule Liblink.Data.BalanceTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Balance

  describe "round_robin" do
    test "empty list" do
      assert :error == Balance.round_robin([])
    end

    test "singleton" do
      assert {:ok, :term} == Balance.round_robin([:term])
    end

    test "eventually selects all elements" do
      test = fn data -> data == MapSet.new(0..10) end

      exec = fn ->
        Balance.round_robin!(0..10)
      end

      assert :ok == do_until(MapSet.new(), test, exec)
    end
  end

  describe "weighted_round_robin" do
    test "empty list" do
      assert :error = Balance.round_robin([])
    end

    test "singleton" do
      assert {:ok, :term} == Balance.weighted_round_robin([{1, :term}])
    end

    test "eventually selects all elements" do
      test = fn data -> data == MapSet.new(0..10) end

      exec = fn ->
        0..10
        |> Enum.with_index()
        |> Balance.weighted_round_robin!()
      end

      assert :ok == do_until(MapSet.new(), test, exec)
    end
  end

  defp do_until(data, test, exec) do
    if test.(data) do
      :ok
    else
      data
      |> MapSet.put(exec.())
      |> do_until(test, exec)
    end
  end
end
