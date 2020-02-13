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

Code.require_file(Path.expand("lib/mix/tasks/compile.liblink.exs", __DIR__))

defmodule Liblink.MixProject do
  use Mix.Project

  def project do
    [
      app: :liblink,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: source_paths(Mix.env()),
      compilers: [:liblink | Mix.compilers()],
      dialyzer: [flags: [:unmatched_returns]]
    ]
  end

  def application do
    [mod: {Liblink, []}, extra_applications: [:logger]]
  end

  defp deps do
    [
      {:jason, "~> 1.0"},
      {:tesla, ">= 1.0.0 and < 2.0.0"},
      {:stream_data, "~> 0.1", only: :test},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:benchee, "~> 0.11", only: :bench, runtime: false}
    ]
  end

  defp source_paths(:test), do: ["lib", "test/lib"]
  defp source_paths(:bench), do: ["lib", "bench/"]
  defp source_paths(_), do: ["lib"]

  defp aliases do
    [clean: ["clean", &make_clean/1]]
  end

  defp make_clean(_) do
    File.rm_rf("priv")
    build_dir = Path.dirname(Mix.Project.build_path())

    if File.exists?(build_dir) do
      for env <- File.ls!(build_dir) do
        buildroot = Path.join(build_dir, env)

        {_, 0} =
          System.cmd(
            "make",
            ["buildroot=#{buildroot}", "clean", "--quiet"],
            into: IO.stream(:stdio, :line)
          )
      end
    end
  end
end
