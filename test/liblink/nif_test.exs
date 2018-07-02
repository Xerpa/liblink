defmodule Liblink.NifTest do
  use ExUnit.Case, async: true

  alias Liblink.Nif

  describe "router / dealer" do
    setup env do
      this = self()
      uniqid = :erlang.unique_integer()

      {pid, ref} =
        if env[:ephemeral] do
          spawn_monitor(fn ->
            receive do
              :halt ->
                :ok

              {:liblink_message, message} ->
                send(this, {:liblink_message, message})
            end
          end)
        else
          {this, nil}
        end

      {:ok, router} =
        Nif.new_socket(
          :router,
          "@inproc:///liblink-nif-test-#{uniqid}",
          "inproc://liblink-nif-test-router-#{uniqid}",
          pid
        )

      {:ok, dealer} =
        Nif.new_socket(
          :dealer,
          ">inproc:///liblink-nif-test-#{uniqid}",
          "inproc://liblink-nif-test-dealer-#{uniqid}",
          pid
        )

      on_exit(fn ->
        Nif.term(router)
        Nif.term(dealer)
      end)

      {:ok, [router: router, dealer: dealer, receiver: {pid, ref}]}
    end

    test "sendmsg/recv single message", state do
      assert :ok == Nif.sendmsg(state.dealer, "ping")
      assert_receive {:liblink_message, ["ping", msgkey]}

      assert :ok == Nif.sendmsg(state.router, [msgkey, "pong"])
      assert_receive {:liblink_message, ["pong"]}
    end

    test "router receives messages asynchronously", state do
      assert :ok == Nif.sendmsg(state.dealer, "ping-0")
      assert :ok == Nif.sendmsg(state.dealer, "ping-1")
      assert :ok == Nif.sendmsg(state.dealer, "ping-2")

      assert_receive {:liblink_message, ["ping-0", _]}
      assert_receive {:liblink_message, ["ping-1", _]}
      assert_receive {:liblink_message, ["ping-2", _]}
    end

    test "dealer receives messages asynchronously", state do
      assert :ok == Nif.sendmsg(state.dealer, "ping-0")
      assert :ok == Nif.sendmsg(state.dealer, "ping-1")
      assert :ok == Nif.sendmsg(state.dealer, "ping-2")

      assert_receive {:liblink_message, ["ping-0", msgkey0]}
      assert_receive {:liblink_message, ["ping-1", msgkey1]}
      assert_receive {:liblink_message, ["ping-2", msgkey2]}

      assert :ok == Nif.sendmsg(state.router, [msgkey2, "pong-2"])
      assert :ok == Nif.sendmsg(state.router, [msgkey1, "pong-1"])
      assert :ok == Nif.sendmsg(state.router, [msgkey0, "pong-0"])

      assert_receive {:liblink_message, ["pong-2"]}
      assert_receive {:liblink_message, ["pong-1"]}
      assert_receive {:liblink_message, ["pong-0"]}
    end

    test "router flow control | stop receiving", state do
      assert :ok == Nif.signal(state.router, :stop)
      :timer.sleep(100)
      assert :waiting == Nif.state(state.router)
      assert :ok == Nif.sendmsg(state.dealer, "ping")

      refute_receive {:liblink_message, _}
    end

    test "router flow control | resume receiving", state do
      assert :ok == Nif.signal(state.router, :stop)
      :timer.sleep(100)
      assert :waiting == Nif.state(state.router)
      assert :ok == Nif.sendmsg(state.dealer, "ping")
      refute_receive {:liblink_message, _}

      assert :ok == Nif.signal(state.router, :cont)
      assert_receive {:liblink_message, ["ping", _]}
      assert :running == Nif.state(state.router)
    end

    test "dealer flow control | stop receiving", state do
      assert :ok == Nif.signal(state.dealer, :stop)
      :timer.sleep(100)
      assert :waiting == Nif.state(state.dealer)
      assert :ok == Nif.sendmsg(state.dealer, "ping")
      assert_receive {:liblink_message, ["ping", msgkey]}
      assert :ok == Nif.sendmsg(state.router, [msgkey, "pong"])

      refute_receive {:liblink_message, _}
    end

    test "dealer flow control | resume receiving", state do
      assert :ok == Nif.signal(state.dealer, :stop)
      :timer.sleep(100)
      assert :waiting == Nif.state(state.dealer)
      assert :ok == Nif.sendmsg(state.dealer, "ping")
      assert_receive {:liblink_message, ["ping", msgkey]}
      assert :ok == Nif.sendmsg(state.router, [msgkey, "pong"])

      refute_receive {:liblink_message, _}
      assert :ok == Nif.signal(state.dealer, :cont)
      assert_receive {:liblink_message, ["pong"]}
      assert :running == Nif.state(state.dealer)
    end

    @tag ephemeral: true
    test "router_device enter waiting state if router vanishes", state do
      {pid, ref} = state.receiver
      send(pid, :halt)
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}
      assert :ok = Nif.sendmsg(state.dealer, "ping")
      refute_receive {:liblink_message, _}
      assert :waiting == Nif.state(state.router)
    end

    @tag ephemeral: true
    test "dealer_device enter waiting state if dealer vanishes", state do
      {pid, ref} = state.receiver
      assert :ok == Nif.sendmsg(state.dealer, "ping")
      assert_receive {:liblink_message, ["ping", msgkey]}
      send(pid, :halt)
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}
      assert :ok == Nif.sendmsg(state.router, [msgkey, "pong"])
      refute_receive {:liblink_message, _}
      assert :waiting == Nif.state(state.dealer)
    end
  end
end
