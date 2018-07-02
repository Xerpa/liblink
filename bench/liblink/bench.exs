alias Liblink.Bench.Client
alias Liblink.Bench.Server
alias Liblink.Bench.Helper

require Logger

client_node =
  with name when is_binary(name) <- System.get_env("client_node") do
    String.to_atom(name)
  end

server_node =
  with name when is_binary(name) <- System.get_env("server_node") do
    String.to_atom(name)
  end

transport =
  if !!client_node or !!server_node do
    "tcp"
  else
    "inproc"
  end

iterations =
  String.to_integer((System.get_env("iterations") || "150_000") |> String.replace("_", ""))

s_message = :crypto.strong_rand_bytes(16)
m_message = :crypto.strong_rand_bytes(256)
l_message = :crypto.strong_rand_bytes(1024)

Benchee.run(
  %{
    "OTP" =>
      {fn {input, client, server} ->
         :done = Server.run(server)
         :done = Client.wait(client)

         {input, client, server}
       end,
       before_each: fn input ->
         {:ok, client} = Client.spawn_task(client_node, Helper.otp_client())

         server_cfg = Helper.otp_server(client)

         {:ok, server} = Server.spawn_task(server_node, server_cfg, input.message, iterations)

         {input, client, server}
       end,
       after_each: fn {_input, client, server} ->
         Server.close(server)
         Client.close(client)

         :timer.sleep(1_000)
       end},
    "NIF" =>
      {fn {input, client, server} ->
         :done = Server.run(server)
         :done = Client.wait(client)

         {input, client, server}
       end,
       before_each: fn input ->
         {:ok, client} =
           Client.spawn_task(client_node, Helper.nif_client("#{transport}://127.0.0.1:5000"))

         {:ok, server} =
           Server.spawn_task(
             server_node,
             Helper.nif_server("#{transport}://127.0.0.1:5000"),
             input.message,
             iterations
           )

         {input, client, server}
       end,
       after_each: fn {_input, client, server} ->
         Server.close(server)
         Client.close(client)

         :timer.sleep(1_000)
       end}
  },
  inputs: %{
    "message_size:#{byte_size(s_message)}" => %{message: s_message},
    "message_size:#{byte_size(m_message)}" => %{message: m_message},
    "message_size:#{byte_size(l_message)}" => %{message: l_message}
  }
)
