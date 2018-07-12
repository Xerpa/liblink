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

defmodule Liblink.Data.KeywordTest do
  use ExUnit.Case, async: true

  alias Liblink.Data.Keyword

  def test_fetcher(fetcher, val, bad_val \\ :invalid) do
    fetch = &apply(Keyword, fetcher, [&1, &2])
    maybe_fetch = &apply(Keyword, String.to_atom("maybe_#{fetcher}"), [&1, &2, &3])
    fetch_default = &apply(Keyword, fetcher, [&1, &2, &3])

    key = :foobar
    opts = [{key, val}]
    bad_opts = [{key, bad_val}]

    assert {:error, {key, :not_found}} == fetch.([], key)
    assert {:ok, val} == fetch_default.([], key, val)
    assert {:ok, val} == maybe_fetch.([], key, val)
    assert {:ok, nil} == maybe_fetch.([], key, nil)

    assert {:ok, val} == fetch.(opts, key)
    assert {:ok, val} == fetch_default.(opts, key, val)
    assert {:ok, val} == maybe_fetch.(opts, key, val)
    assert {:ok, val} == maybe_fetch.(opts, key, nil)

    assert {:error, {key, {:value, bad_val}}} == fetch.(bad_opts, key)
    assert {:error, {key, {:value, bad_val}}} == fetch_default.(bad_opts, key, val)
    assert {:error, {key, {:value, bad_val}}} == maybe_fetch.(bad_opts, key, val)
    assert {:error, {key, {:value, bad_val}}} == maybe_fetch.(bad_opts, key, nil)
  end

  describe "fetch_struct" do
    setup do
      setup = [
        key: :foobar,
        val: MapSet.new(),
        bad_val: :bad_val,
        structs: [MapSet, [MapSet]],
        opts: [foobar: MapSet.new()],
        bad_opts: [foobar: :bad_val]
      ]

      {:ok, setup}
    end

    test "fetch", data do
      for struct <- data.structs do
        assert {:ok, data.val} == Keyword.fetch_struct(data.opts, data.key, struct)
        assert {:error, {data.key, :not_found}} == Keyword.fetch_struct([], data.key, struct)

        assert {:error, {data.key, {:value, data.bad_val}}} ==
                 Keyword.fetch_struct(data.bad_opts, data.key, struct)
      end
    end

    test "fetch with default", data do
      for struct <- data.structs do
        assert {:ok, data.val} == Keyword.fetch_struct(data.opts, data.key, struct, data.val)
        assert {:ok, data.val} == Keyword.fetch_struct([], data.key, struct, data.val)

        assert {:error, {data.key, {:value, data.bad_val}}} ==
                 Keyword.fetch_struct(data.bad_opts, data.key, struct)
      end
    end

    test "maybe_fetch", data do
      for struct <- [MapSet, [MapSet]] do
        assert {:ok, data.val} == Keyword.maybe_fetch_struct(data.opts, data.key, struct)
        assert {:ok, data.val} == Keyword.maybe_fetch_struct(data.opts, data.key, struct, nil)

        assert {:ok, data.val} ==
                 Keyword.maybe_fetch_struct(data.opts, data.key, struct, data.val)

        assert {:ok, nil} == Keyword.maybe_fetch_struct([], data.key, struct)
        assert {:ok, nil} == Keyword.maybe_fetch_struct([], data.key, struct, nil)
        assert {:ok, data.val} == Keyword.maybe_fetch_struct([], data.key, struct, data.val)

        assert {:error, {data.key, {:value, data.bad_val}}} ==
                 Keyword.maybe_fetch_struct(data.bad_opts, data.key, struct)

        assert {:error, {data.key, {:value, data.bad_val}}} ==
                 Keyword.maybe_fetch_struct(data.bad_opts, data.key, struct, data.val)

        assert {:error, {data.key, {:value, data.bad_val}}} ==
                 Keyword.maybe_fetch_struct(data.bad_opts, data.key, struct, nil)
      end
    end
  end

  test "fetch_bool" do
    test_fetcher(:fetch_bool, true)
  end

  test "fetch_atom" do
    test_fetcher(:fetch_atom, :atom, "bad_val")
  end

  test "fetch_map" do
    test_fetcher(:fetch_map, %{})
  end

  test "fetch_list" do
    test_fetcher(:fetch_list, [])
  end

  test "fetch_tuple" do
    test_fetcher(:fetch_tuple, {})
  end

  test "fetch_binary" do
    test_fetcher(:fetch_binary, "")
  end

  test "fetch_function" do
    test_fetcher(:fetch_function, fn -> :ok end)
  end

  test "fetch_integer" do
    test_fetcher(:fetch_integer, 0)
  end
end
