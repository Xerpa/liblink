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

defmodule Mix.Tasks.Compile.Liblink do
  use Mix.Task

  @shortdoc "compiles the liblink library"
  def run(_) do
    distroot = Path.absname(Path.expand("priv", __DIR__))
    buildroot = Mix.Project.build_path()

    runcmd("make", [
      "--quiet",
      "distroot=#{distroot}",
      "buildroot=#{buildroot}",
      "compile",
      "install"
    ])

    Mix.Project.build_structure()
  end

  defp runcmd(cmd, args) do
    {_, 0} = System.cmd(cmd, args, into: IO.stream(:stdio, :line))
  end
end

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
      dialyzer: [
        paths:
          "_build/dev/**/*.beam"
          |> Path.wildcard()
          |> Enum.filter(&String.contains?(&1, "Elixir.Liblink."))
          |> Enum.reject(&String.contains?(&1, "Elixir.Liblink.Hidden.beam")),
        remove_defaults: [:unknown],
        flags: [:underspecs, :unmatched_returns]
      ]
    ]
  end

  def application do
    [mod: {Liblink, []}, extra_applications: [:logger]]
  end

  defp deps do
    [
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
