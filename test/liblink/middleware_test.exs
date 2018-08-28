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

defmodule Liblink.MiddlewareTest do
  use ExUnit.Case, async: true

  alias Liblink.Middleware
  alias Liblink.Data.Message
  alias Liblink.TestHaltMiddleware

  @moduletag capture_log: true

  describe "adive_ext" do
    test "valid forms" do
      assert {:ok, Message.new(nil)} ==
               with_mock(
                 fn m -> {:ok, m} end,
                 fn ->
                   Middleware.advise_ext(__MODULE__, :mock, Message.new(nil))
                 end
               )

      assert {:error, :error} ==
               with_mock(
                 fn _ -> {:error, :error} end,
                 fn ->
                   Middleware.advise_ext(__MODULE__, :mock, Message.new(nil))
                 end
               )

      assert {:error, :error, Message.new(:error)} ==
               with_mock(
                 fn _ -> {:error, :error, Message.new(:error)} end,
                 fn ->
                   Middleware.advise_ext(__MODULE__, :mock, Message.new(nil))
                 end
               )
    end

    test "on invalid form" do
      assert {:error, :bad_service} ==
               with_mock(
                 fn _ -> {:invalid, :reply} end,
                 fn ->
                   Middleware.advise_ext(__MODULE__, :mock, Message.new(nil))
                 end
               )
    end

    test "add except middleware" do
      assert {:error, :internal_error, Message.new(%RuntimeError{message: "foobar"})} ==
               with_mock(
                 fn _ -> raise(RuntimeError, message: "foobar") end,
                 fn ->
                   Middleware.advise_ext(__MODULE__, :mock, Message.new(nil))
                 end
               )
    end
  end

  describe "middleware" do
    test "define an __advise__ function" do
      assert {:error, :halt} == TestHaltMiddleware.__advise__(:foobar, Message.new(nil))
    end

    test "keeps the original function untouched" do
      assert {:ok, Message.new(nil)} == TestHaltMiddleware.foobar(Message.new(nil))
    end
  end

  def mock(message) do
    handler = Process.get(:handler)
    handler.(message)
  end

  def with_mock(handler, expr) when is_function(handler, 1) do
    Task.async(fn ->
      Process.put(:handler, handler)
      expr.()
    end)
    |> Task.await(:infinity)
  end
end
