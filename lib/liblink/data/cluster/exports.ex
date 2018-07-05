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

defmodule Liblink.Data.Cluster.Exports do
  alias Liblink.Data.Cluster.Exports.Module, as: ModExport

  import Liblink.Data.Macros

  @spec new!(:module, [ModExports.option()]) :: ModExport.t()
  def_bang(:new, 2)

  @spec new(:module, [ModExports.option()]) :: {:ok, ModExport.t()} | Keyword.fetch_error()
  def new(:module, options) when is_list(options) do
    ModExport.new(options)
  end
end
