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

defmodule Liblink.Network.Consul.Agent do
  alias Liblink.Data.Consul.Service

  @type check_option :: {:note, String.t()}

  @spec service_register(Tesla.Client.t(), Service.t()) :: Tesla.Env.result()
  def service_register(client = %Tesla.Client{}, service = %Service{}) do
    payload = Jason.encode!(Service.to_consul(service))
    Tesla.put(client, "/v1/agent/service/register", payload)
  end

  @spec service_deregister(Tesla.Client.t(), String.t()) :: Tesla.Env.result()
  def service_deregister(client = %Tesla.Client{}, service_id) when is_binary(service_id) do
    Tesla.put(client, "/v1/agent/service/deregister/#{service_id}", "")
  end

  @spec services(Tesla.Client.t()) :: Tesla.Env.result()
  def services(client = %Tesla.Client{}) do
    Tesla.get(client, "/v1/agent/services")
  end

  @spec service(Tesla.Client.t(), String.t()) :: Tesla.Env.result()
  def service(client = %Tesla.Client{}, service_id) when is_binary(service_id) do
    with {:ok, reply = %{status: 200}} <- services(client) do
      {:ok,
       Map.update(reply, :body, nil, fn body ->
         body
         |> Enum.filter(fn {service, _} -> service == service_id end)
         |> Map.new()
       end)}
    end
  end

  @spec check_pass(Tesla.Client.t(), String.t()) :: Tesla.Env.result()
  @spec check_pass(Tesla.Client.t(), String.t(), [check_option]) :: Tesla.Env.result()
  def check_pass(client = %Tesla.Client{}, check_id, params \\ []) when is_binary(check_id) do
    payload = Jason.encode!(Map.new(params))
    Tesla.put(client, "/v1/agent/check/pass/#{check_id}", payload)
  end

  @spec check_warn(Tesla.Client.t(), String.t()) :: Tesla.Env.result()
  @spec check_warn(Tesla.Client.t(), String.t(), [check_option]) :: Tesla.Env.result()
  def check_warn(client = %Tesla.Client{}, check_id, params \\ []) when is_binary(check_id) do
    payload = Jason.encode!(Map.new(params))
    Tesla.put(client, "/v1/agent/check/warn/#{check_id}", payload)
  end

  @spec check_fail(Tesla.Client.t(), String.t()) :: Tesla.Env.result()
  @spec check_fail(Tesla.Client.t(), String.t(), [check_option]) :: Tesla.Env.result()
  def check_fail(client = %Tesla.Client{}, check_id, params \\ []) when is_binary(check_id) do
    payload = Jason.encode!(Map.new(params))
    Tesla.put(client, "/v1/agent/check/fail/#{check_id}", payload)
  end

  @spec checks(Tesla.Client.t()) :: Tesla.Env.result()
  def checks(client = %Tesla.Client{}) do
    Tesla.get(client, "/v1/agent/checks")
  end

  @spec check(Tesla.Client.t(), String.t()) :: Tesla.Env.result()
  def check(client = %Tesla.Client{}, check_id) do
    with {:ok, reply = %{status: 200}} <- checks(client) do
      {:ok,
       Map.update(reply, :body, nil, fn body ->
         body
         |> Enum.filter(fn {check, _} -> check == check_id end)
         |> Map.new()
       end)}
    end
  end
end
