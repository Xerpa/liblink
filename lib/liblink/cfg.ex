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

defmodule Liblink.Cfg do
  @spec protocol_host(:request_response) :: String.t() | nil
  def protocol_host(protocol) when protocol == :request_response do
    with netcfg when is_list(netcfg) <- Application.get_env(:liblink, :netcfg, []),
         protocfg when is_list(protocfg) <- Keyword.get(netcfg, :request_response, []),
         host when is_binary(host) <- Keyword.get(protocfg, :host) do
      host
    else
      _ -> nil
    end
  end

  @spec protocol_port(:request_response) :: String.t() | nil
  def protocol_port(protocol) when protocol == :request_response do
    with netcfg when is_list(netcfg) <- Application.get_env(:liblink, :netcfg, []),
         protocfg when is_list(protocfg) <- Keyword.get(netcfg, :request_response, []),
         port <- Keyword.get(protocfg, :port) do
      case port do
        %Range{first: min, last: max} when min > 0 and max <= 0xFFFF ->
          port

        _port when is_integer(port) and port > 0 and port <= 0xFFFF ->
          port

        _otherwise ->
          nil
      end
    else
      _ -> nil
    end
  end
end
