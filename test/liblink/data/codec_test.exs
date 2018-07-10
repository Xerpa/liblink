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

defmodule Liblink.Data.CodecTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Liblink.Data.Codec

  property "encode . decode = id" do
    check all meta <- map_of(one_of([binary(), atom(:alphanumeric)]), term()),
              payload <- term() do
      assert {:ok, {meta, payload}} == Codec.decode(Codec.encode(meta, payload))
    end
  end

  test "decode on invalid data" do
    assert :error == Codec.decode("bad_data")
  end
end
