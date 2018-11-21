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

defmodule Liblink.Middleware.Except do
  @behaviour Liblink.Middleware

  use Liblink.Logger

  alias Liblink.Data.Message

  @impl true
  def call(request, {module, function}, _data, continue) do
    try do
      continue.(request)
    rescue
      except ->
        message = Exception.format(:error, except, System.stacktrace())

        Liblink.Logger.warn(fn ->
          "exception calling #{module}.#{function}\n\n" <> message
        end)

        {:error, :internal_error, Message.new(except)}
    end
  end
end
