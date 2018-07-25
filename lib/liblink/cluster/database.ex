defmodule Liblink.Cluster.Database do
  use GenServer

  alias Liblink.Data.Keyword
  alias Liblink.Cluster.Database.Hook
  alias Liblink.Cluster.Database.UniqConstraint

  @type t :: pid | atom

  @type tid :: :ets.tid()

  @typep state_t :: %{tid: tid, hooks: [Hook.t()]}

  @spec start_link([{:hooks, [Hook.t()]}], [{:name, atom}]) ::
          {:ok, pid} | {:error, {:already_started, pid}}
  def start_link(args, opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(args) do
    {:ok, hooks} = Keyword.fetch_list(args, :hooks, [])

    tid = :ets.new(__MODULE__, [:protected, read_concurrency: true])

    {:ok, %{tid: tid, hooks: hooks, subscriptions: Map.new()}}
  end

  @spec subscribe(pid, pid) :: :ok
  def subscribe(pid, subscriber) do
    GenServer.cast(pid, {:subscribe, subscriber})
  end

  @spec unsubscribe(pid, pid) :: :ok
  def unsubscribe(pid, subscriber) do
    GenServer.cast(pid, {:unsubscribe, subscriber})
  end

  @spec put_async(t, term, term) :: :ok
  def put_async(pid, key, val) do
    GenServer.cast(pid, {:put, key, val, []})
  end

  @spec del_async(t, term) :: :ok
  def del_async(pid, key) do
    GenServer.cast(pid, {:del, key, []})
  end

  @spec fetch_sync(t, term) :: {:ok, term} | :error
  def fetch_sync(pid, key, timeout \\ 1_000) do
    GenServer.call(pid, {:fetch, key}, timeout)
  end

  @spec put(t, term, term) :: :ok | :error
  @spec put(t, term, term, timeout) :: :ok | :error
  def put(pid, key, val, timeout \\ 1_000) do
    GenServer.call(pid, {:put, key, val, []}, timeout)
  end

  @spec put_new(t, term, term) :: :ok | :error
  @spec put_new(t, term, term, timeout) :: :ok | :error
  def put_new(pid, key, val, timeout \\ 1_000) do
    hooks = [UniqConstraint]
    GenServer.call(pid, {:put, key, val, hooks}, timeout)
  end

  @spec del(t, term, timeout) :: :ok | :error
  def del(pid, key, timeout \\ 1_000) do
    GenServer.call(pid, {:del, key, []}, timeout)
  end

  @spec get_tid(t, timeout) :: {:ok, tid}
  def get_tid(pid, timeout \\ 1_000) do
    GenServer.call(pid, {:get, :tid}, timeout)
  end

  @spec get(tid, term, term) :: term
  def get(tid, key, default \\ nil) do
    case fetch(tid, key) do
      :error -> default
      {:ok, val} -> val
    end
  end

  @spec fetch(tid, term) :: {:ok, term} | term
  def fetch(tid, key) do
    case :ets.lookup(tid, key) do
      [{^key, val}] -> {:ok, val}
      [] -> :error
    end
  end

  @spec select(tid, :ets.match_spec()) :: term
  def select(tid, pattern) do
    :ets.select(tid, pattern)
  end

  @impl true
  def handle_call(message, _from, state) do
    result =
      case message do
        {:put, key, value, hooks} ->
          put_value(state, key, value, hooks)

        {:del, key, hooks} ->
          del_value(state, key, hooks)

        {:get, :tid} ->
          {:ok, state.tid}

        {:get, {:key, key}} ->
          get(state.tid, key)

        {:fetch, key} ->
          fetch(state.tid, key)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast(message, state) do
    case message do
      {:put, key, value, hooks} ->
        put_value(state, key, value, hooks)
        {:noreply, state}

      {:del, key, hooks} ->
        del_value(state, key, hooks)
        {:noreply, state}

      {:subscribe, pid} ->
        tag = Process.monitor(pid)
        state = Map.update!(state, :subscriptions, &Map.put(&1, tag, pid))

        {:noreply, state}

      {:unsubscribe, pid} ->
        entry = Enum.find(state.subscriptions, fn {_, val} -> val == pid end)

        state =
          case entry do
            {tag, _pid} ->
              Process.demonitor(tag)

              Map.update!(state, :subscriptions, &Map.delete(&1, tag))

            nil ->
              state
          end

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(message, state) do
    case message do
      {:DOWN, tag, :process, _pid, _reason} ->
        state = Map.update!(state, :subscriptions, &Map.delete(&1, tag))
        {:noreply, state}
    end
  end

  @spec put_value(state_t, term, term, [Hook.t()]) :: :ok | :error
  defp put_value(state, key, next_value, hooks) do
    tid = state.tid
    hooks = hooks ++ state.hooks
    prev_value = get(tid, key, nil)
    event = {:put, key, prev_value, next_value}

    with :ok <- Hook.call_before_hooks(hooks, event) do
      :ets.insert(tid, {key, next_value})
      Hook.call_after_hooks(hooks, self(), state.tid, event)

      Enum.each(state.subscriptions, fn {_tag, pid} ->
        Process.send(pid, {__MODULE__, self(), tid, event}, [])
      end)
    end
  end

  @spec del_value(state_t, term, [Hook.t()]) :: :ok | :error
  defp del_value(state, key, hooks) do
    tid = state.tid
    hooks = hooks ++ state.hooks
    value = get(tid, key, nil)
    event = {:del, key, value}

    with :ok <- Hook.call_before_hooks(hooks, event) do
      :ets.delete(tid, key)
      Hook.call_after_hooks(hooks, self(), tid, event)

      Enum.each(state.subscriptions, fn {_tag, pid} ->
        Process.send(pid, {__MODULE__, self(), tid, event}, [])
      end)
    end
  end
end
