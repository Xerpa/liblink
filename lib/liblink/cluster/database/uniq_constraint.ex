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

defmodule Liblink.Cluster.Database.UniqConstraint do
  use Liblink.Cluster.Database.Hook

  @impl true
  def before_hook(event) do
    case event do
      {:put, _key, prev_value, _} ->
        is_nil(prev_value)

      _ ->
        true
    end
  end
end
