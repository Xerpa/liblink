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

defmodule Liblink.Middleware.ExceptTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Message
  alias Liblink.Middleware.Except

  @moduletag capture_log: true

  describe "call" do
    test "capture exception" do
      expected = {:error, :internal_error, Message.new(%RuntimeError{message: "foobar"})}

      assert expected ==
               Except.call(Message.new(nil), :unused, fn _ ->
                 raise(RuntimeError, message: "foobar")
               end)
    end

    test "bypass otherwise" do
      assert {:ok, nil} ==
               Except.call(Message.new(nil), :unused, fn _ ->
                 {:ok, nil}
               end)
    end
  end
end
