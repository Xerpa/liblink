defmodule Liblink.NifTest do
  use ExUnit.Case, async: true

  alias Liblink.Nif
  alias Test.Liblink.Socket

  describe "router / dealer" do
    setup do
      Nif.load()

      session = :erlang.unique_integer([:positive])

      {:ok, router} = Socket.start_link()
      {:ok, dealer} = Socket.start_link()

      {:ok, router_device} =
        Nif.new_socket(
          :router,
          "@inproc:///liblink-nif-test-#{session}",
          "inproc://liblink-niftest-router-#{session}",
          router
        )

      {:ok, dealer_device} =
        Nif.new_socket(
          :dealer,
          ">inproc:///liblink-nif-test-#{session}",
          "inproc://liblink-niftest-dealer-#{session}",
          dealer
        )

      on_exit(fn ->
        Nif.term(router_device)
        Nif.term(dealer_device)
      end)

      {:ok,
       [
         router: router,
         dealer: dealer,
         router_device: router_device,
         dealer_device: dealer_device
       ]}
    end

    test "send/recv single message", state do
      assert :ok == Nif.send(state.dealer_device, "ping")
      assert {:ok, [msgk, "ping"]} = GenServer.call(state.router, :pop)
      assert :ok == Nif.send(state.router_device, [msgk, "pong"])
      assert {:ok, ["pong"]} == GenServer.call(state.dealer, :pop)
    end

    test "router receives messages asynchronously", state do
      assert :ok == Nif.send(state.dealer_device, "ping-0")
      assert :ok == Nif.send(state.dealer_device, "ping-1")
      assert :ok == Nif.send(state.dealer_device, "ping-2")

      assert {:ok, [_, "ping-0"]} = GenServer.call(state.router, :pop)
      assert {:ok, [_, "ping-1"]} = GenServer.call(state.router, :pop)
      assert {:ok, [_, "ping-2"]} = GenServer.call(state.router, :pop)
    end

    test "dealer receives messages asynchronously", state do
      assert :ok == Nif.send(state.dealer_device, "ping-0")
      assert :ok == Nif.send(state.dealer_device, "ping-1")
      assert :ok == Nif.send(state.dealer_device, "ping-2")

      assert {:ok, [msgk0, "ping-0"]} = GenServer.call(state.router, :pop)
      assert {:ok, [msgk1, "ping-1"]} = GenServer.call(state.router, :pop)
      assert {:ok, [msgk2, "ping-2"]} = GenServer.call(state.router, :pop)

      assert :ok == Nif.send(state.router_device, [msgk2, "pong-2"])
      assert :ok == Nif.send(state.router_device, [msgk1, "pong-1"])
      assert :ok == Nif.send(state.router_device, [msgk0, "pong-0"])

      assert {:ok, ["pong-2"]} = GenServer.call(state.dealer, :pop)
      assert {:ok, ["pong-1"]} = GenServer.call(state.dealer, :pop)
      assert {:ok, ["pong-0"]} = GenServer.call(state.dealer, :pop)
    end

    test "router flow control | stop receiving", state do
      assert :ok == Nif.signal(state.router_device, :stop)
      :timer.sleep(100) # allow the zloop to cancel the reader
      assert :ok == Nif.send(state.dealer_device, "ping")

      assert {:error, :timeout} == GenServer.call(state.router, :pop)
    end

    test "router flow control | resume receiving", state do
      assert :ok == Nif.signal(state.router_device, :stop)
      :timer.sleep(100)
      assert :waiting == Nif.state(state.router_device)
      assert :ok == Nif.send(state.dealer_device, "ping")

      assert {:error, :timeout} == GenServer.call(state.router, :pop)
      assert :ok == Nif.signal(state.router_device, :cont)
      assert {:ok, [_, "ping"]} = GenServer.call(state.router, :pop)
      assert :running == Nif.state(state.router_device)
    end

    test "dealer flow control | stop receiving", state do
      assert :ok == Nif.signal(state.dealer_device, :stop)
      :timer.sleep(100)
      assert :waiting == Nif.state(state.dealer_device)
      assert :ok == Nif.send(state.dealer_device, "ping")
      assert {:ok, [msgk, "ping"]} = GenServer.call(state.router, :pop)
      assert :ok == Nif.send(state.router_device, [msgk, "pong"])

      assert {:error, :timeout} = GenServer.call(state.dealer, :pop)
    end

    test "dealer flow control | resume receiving", state do
      assert :ok == Nif.signal(state.dealer_device, :stop)
      :timer.sleep(100)
      assert :waiting == Nif.state(state.dealer_device)
      assert :ok == Nif.send(state.dealer_device, "ping")
      assert {:ok, [msgk, "ping"]} = GenServer.call(state.router, :pop)
      assert :ok == Nif.send(state.router_device, [msgk, "pong"])

      assert {:error, :timeout} = GenServer.call(state.dealer, :pop)
      assert :ok == Nif.signal(state.dealer_device, :cont)
      assert {:ok, ["pong"]} == GenServer.call(state.dealer, :pop)
      assert :running == Nif.state(state.dealer_device)
    end

    test "router_device enter waiting state if router vanishes", state do
      GenServer.stop(state.router)

      refute Process.alive?(state.router)
      assert :ok = Nif.send(state.dealer_device, "ping")
      :timer.sleep(100)
      assert :waiting == Nif.state(state.router_device)
    end

    test "dealer_device enter waiting state if dealer vanishes", state do
      assert :ok == Nif.send(state.dealer_device, "ping")
      assert {:ok, [msgk, "ping"]} = GenServer.call(state.router, :pop)

      GenServer.stop(state.dealer)

      refute Process.alive?(state.dealer)
      assert :ok == Nif.send(state.router_device, [msgk, "pong"])
      :timer.sleep(100)
      assert :waiting == Nif.state(state.dealer_device)
    end
  end
end
