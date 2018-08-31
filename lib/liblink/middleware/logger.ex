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

defmodule Liblink.Middleware.Logger do
  @behaviour Liblink.Middleware

  use Liblink.Logger
  use Liblink.Middleware

  @impl true
  def call(request, _data, continue) do
    offset = :erlang.monotonic_time()

    case continue.(request) do
      reply = {:ok, _term} ->
        {duration, unit} = normalize(:erlang.monotonic_time() - offset, :native)

        Liblink.Logger.info(fn ->
          Enum.join(["success", " duration=#{duration}#{unit}", " request=#{inspect(request)}"])
        end)

        reply

      reply ->
        {duration, unit} = normalize(:erlang.monotonic_time() - offset, :native)

        Liblink.Logger.warn(fn ->
          Enum.join([
            "failure",
            " duration=#{duration}#{unit}",
            " request=#{inspect(request)}",
            " reply=#{inspect(reply)}"
          ])
        end)

        reply
    end
  end

  defp normalize(duration, :native) do
    normalize(:erlang.convert_time_unit(duration, :native, :nanosecond), :ns)
  end

  defp normalize(duration, unit) do
    if duration > 1000_000 do
      case unit do
        :ns ->
          normalize(div(duration, 1000), :us)

        :us ->
          normalize(div(duration, 1000), :ms)

        :ms ->
          normalize(div(duration, 1000), :s)

        :s ->
          {duration, :s}
      end
    else
      {duration, unit}
    end
  end
end
