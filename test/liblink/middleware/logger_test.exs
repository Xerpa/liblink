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

defmodule Liblink.Middleware.LoggerTest do
  use ExUnit.Case, async: true

  alias Liblink.Middleware.Logger

  import ExUnit.CaptureLog

  describe "call" do
    test "log success when ans = {:ok, _term}" do
      logline =
        capture_log(fn ->
          Logger.call(:foobar, :any, fn _ -> {:ok, :any} end)
        end)

      assert String.contains?(logline, "success")
    end

    test "log failure when ans != {:ok, _term}" do
      logline =
        capture_log(fn ->
          Logger.call(:foobar, :any, fn _ -> {:error, :error} end)
        end)

      assert String.contains?(logline, "failure")
    end
  end
end
