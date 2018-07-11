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

defmodule Liblink.TimeoutTest do
  use ExUnit.Case, async: true

  alias Liblink.Timeout

  describe "deadline" do
    test "deadline with negative numbers is always expired" do
      assert Timeout.deadline_expired?(Timeout.deadline(-1, :second))
    end

    test "a deadline is always valid with a positive number" do
      refute Timeout.deadline_expired?(Timeout.deadline(1, :second))
    end

    test "deadline expires eventually" do
      deadline = Timeout.deadline(1, :millisecond)

      refute Timeout.deadline_expired?(deadline)

      Process.sleep(2)

      assert Timeout.deadline_expired?(deadline)
    end

    test "infinity never expires" do
      refute Timeout.deadline_expired?(:infinity)
    end
  end

  describe "timeout_mul" do
    test "is never negative" do
      assert 0 >= Timeout.timeout_mul(1, -1)
    end

    test "is always integer" do
      assert is_integer(Timeout.timeout_mul(1, 0.5))
    end

    test "infinity * x == infinity" do
      assert :infinity == Timeout.timeout_mul(:infinity, -1)
      assert :infinity == Timeout.timeout_mul(:infinity, 0)
      assert :infinity == Timeout.timeout_mul(:infinity, 1)
    end
  end
end
