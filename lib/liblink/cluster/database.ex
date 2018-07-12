defmodule Liblink.Cluster.Database do
  use GenServer

  alias Liblink.Data.Keyword
  alias Liblink.Cluster.Database.Hook
  alias Liblink.Cluster.Database.UniqConstraint

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def put_async(pid, key, val) do
    GenServer.cast(pid, {:put, key, val, []})
  end

  def del_async(pid, key) do
    GenServer.cast(pid, {:del, key, []})
  end

  def fetch_async(pid, key) do
    tag = :erlang.make_ref()

    with :ok <- GenServer.cast(pid, {:fetch, key, {tag, self()}}) do
      {:ok, tag}
    end
  end

  def put(pid, key, val, timeout \\ 1_000) do
    GenServer.call(pid, {:put, key, val, []}, timeout)
  end

  def put_new(pid, key, val, timeout \\ 1_000) do
    hooks = [UniqConstraint]
    GenServer.call(pid, {:put, key, val, hooks}, timeout)
  end

  def del(pid, key, timeout \\ 1_000) do
    GenServer.call(pid, {:del, key, []}, timeout)
  end

  def get_tid(pid, timeout \\ 1_000) do
    GenServer.call(pid, {:get, :tid}, timeout)
  end

  def get(tid, key, default \\ nil) when is_reference(tid) do
    case fetch(tid, key) do
      :error -> default
      {:ok, val} -> val
    end
  end

  def fetch(tid, key) when is_reference(tid) do
    case :ets.lookup(tid, key) do
      [{^key, val}] -> {:ok, val}
      [] -> :error
    end
  end

  @impl true
  def init(args) do
    {:ok, hooks} = Keyword.fetch_list(args, :hooks, [])

    tid = :ets.new(__MODULE__, [:protected, read_concurrency: true])

    {:ok, %{tid: tid, hooks: hooks}}
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
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast(message, state) do
    case message do
      {:put, key, value, hooks} ->
        put_value(state, key, value, hooks)

      {:del, key, hooks} ->
        del_value(state, key, hooks)

      {:fetch, key, {tag, from}} ->
        send(from, {tag, fetch(state.tid, key)})
    end

    {:noreply, state}
  end

  defp put_value(state, key, next_value, hooks) do
    tid = state.tid
    hooks = hooks ++ state.hooks
    prev_value = get(tid, key, nil)
    event = {:put, key, prev_value, next_value}

    with :ok <- Hook.call_before_hooks(hooks, event) do
      :ets.insert(tid, {key, next_value})
      Hook.call_after_hooks(hooks, self(), state.tid, event)
    end
  end

  defp del_value(state, key, hooks) do
    tid = state.tid
    hooks = hooks ++ state.hooks
    value = get(tid, key, nil)
    event = {:del, key, value}

    with :ok <- Hook.call_before_hooks(hooks, event) do
      :ets.delete(tid, key)
      Hook.call_after_hooks(hooks, self(), tid, event)
    end
  end
end
