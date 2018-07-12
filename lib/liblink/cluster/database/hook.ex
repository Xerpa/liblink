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

defmodule Liblink.Cluster.Database.Hook do
  @type event :: {:put | :del, key :: term, old_value :: term, new_value :: term}

  @callback before_hook(event) :: boolean

  @callback after_hook(pid, reference, event) :: term

  defmacro __using__(_args) do
    quote do
      @behaviour Liblink.Cluster.Database.Hook

      @impl true
      def before_hook(_), do: true

      @impl true
      def after_hook(_, _, _), do: nil

      defoverridable Liblink.Cluster.Database.Hook
    end
  end

  def call_before_hooks(hooks, event) do
    Enum.reduce_while(hooks, :ok, fn hook, _ ->
      if hook.before_hook(event) do
        {:cont, :ok}
      else
        {:halt, :error}
      end
    end)
  end

  def call_after_hooks(hooks, pid, tid, event) do
    Enum.each(hooks, fn hook ->
      hook.after_hook(pid, tid, event)
    end)
  end
end
