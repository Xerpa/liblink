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

defmodule Test.Liblink.TestDBHook do
  defmacro __using__(_args) do
    quote do
      use Liblink.Cluster.Database.Hook

      def after_hook(_pid, tid, event) do
        with {:ok, test_pid} <- Liblink.Cluster.Database.fetch(tid, __MODULE__) do
          send(test_pid, event)
        end
      end

      def init_database(pid) do
        Liblink.Cluster.Database.put(pid, __MODULE__, self())

        receive do
          {:put, _key, _oldv, _newv} -> :ok
        after
          100 -> :error
        end
      end
    end
  end
end
