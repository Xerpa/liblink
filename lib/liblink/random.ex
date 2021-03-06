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

defmodule Liblink.Random do
  @spec random_inproc_endpoint() :: String.t()
  def random_inproc_endpoint() do
    suffix =
      Enum.join(
        [
          __MODULE__,
          :erlang.unique_integer(),
          :erlang.monotonic_time()
        ],
        "-"
      )

    "inproc://" <> suffix
  end

  @spec random_ipc_endpoint() :: String.t()
  def random_ipc_endpoint() do
    suffix =
      Enum.join(
        [
          __MODULE__,
          :erlang.unique_integer(),
          :erlang.monotonic_time(),
          :erlang.system_info(:scheduler_id)
        ],
        "-"
      )

    tmpdir = System.get_env("TMPDIR") || "/tmp"
    tmpfile = Path.join(tmpdir, suffix)

    "ipc://" <> tmpfile
  end

  @spec random_tcp_endpoint(
          String.t(),
          :seq | :rnd | Range.t() | {:rnd, Range.t()} | {:seq, Range.t()}
        ) :: String.t()
  def random_tcp_endpoint(host, port_spec \\ :rnd) do
    case port_spec do
      range = %Range{} ->
        random_tcp_endpoint(host, {:rnd, range})

      :seq ->
        "tcp://" <> host <> ":*"

      :rnd ->
        "tcp://" <> host <> ":!"

      {:rnd, range = %Range{}} ->
        ports = "[#{range.first}-#{range.last}]"
        "tcp://" <> host <> ":!" <> ports

      {:seq, range = %Range{}} ->
        ports = "[#{range.first}-#{range.last}]"
        "tcp://" <> host <> ":*" <> ports
    end
  end
end
