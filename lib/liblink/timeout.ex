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

defmodule Liblink.Timeout do
  import Liblink.Guards

  @type deadline_t :: :infinity | integer

  @spec deadline(integer, :nanosecond | :microsecond | :millisecond | :second) :: deadline_t
  def deadline(timeout, unit) when is_integer(timeout) and is_atom(unit) do
    :erlang.monotonic_time() + :erlang.convert_time_unit(timeout, unit, :native)
  end

  @spec deadline_expired?(deadline_t) :: boolean
  def deadline_expired?(deadline) when is_integer(deadline) or is_atom(deadline) do
    deadline_expired?(deadline, current())
  end

  @spec deadline_expired?(deadline_t, deadline_t) :: boolean
  def deadline_expired?(:infinity, _), do: false
  def deadline_expired?(_, :infinity), do: false

  def deadline_expired?(deadline, sysnow) when is_integer(deadline) and is_integer(sysnow) do
    sysnow > deadline
  end

  @spec current() :: deadline_t
  def current() do
    :erlang.monotonic_time()
  end

  @spec timeout_mul(timeout, float | integer) :: timeout
  def timeout_mul(:infinity, _), do: :infinity

  def timeout_mul(timeout, factor)
      when is_timeout(timeout) and (is_float(factor) or is_integer(factor)) do
    max(0, trunc(timeout * factor))
  end
end
