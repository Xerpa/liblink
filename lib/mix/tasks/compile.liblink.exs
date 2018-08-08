defmodule Mix.Tasks.Compile.Liblink do
  use Mix.Task

  @shortdoc "compiles the liblink library"
  def run(_) do
    distroot = Path.absname(Path.expand("../../../priv", __DIR__))
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
