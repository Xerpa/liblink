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

defmodule Liblink.Guards do
  defguard is_iodata(term) when is_list(term) or is_binary(term)

  defguard is_socket_type(term) when term == :router or term == :dealer

  defguard is_signal(term) when term == :stop or term == :cont

  # XXX: term >= 0 for testing purposes
  defguard is_timeout(term) when term == :infinity or (is_integer(term) and term >= 0)
end
