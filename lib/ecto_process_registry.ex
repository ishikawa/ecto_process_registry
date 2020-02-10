defmodule EctoProcessRegistry do
  @moduledoc """
  Documentation for EctoProcessRegistry.
  """
  use GenServer

  alias EctoProcessRegistry.{Name, Pid}

  import Ecto.Query

  require Logger

  @spec start_link([option] | GenServer.options()) :: GenServer.on_start()
        when option: {:name, atom} | {:repo, Ecto.Repo.t()}
  def start_link(options) do
    name =
      case Keyword.fetch(options, :name) do
        {:ok, name} when is_atom(name) ->
          name

        {:ok, other} ->
          raise ArgumentError, "expected :name to be an atom, got: #{inspect(other)}"

        :error ->
          raise ArgumentError, "expected :name option to be present"
      end

    repo =
      case Keyword.fetch(options, :repo) do
        {:ok, repo} when is_atom(repo) ->
          repo

        {:ok, other} ->
          raise ArgumentError, "expected :repo to be a Ecto.Repo module, got: #{inspect(other)}"

        :error ->
          raise ArgumentError, "expected :repo option to be present"
      end

    GenServer.start_link(__MODULE__, %{name: name, repo: repo}, options)
  end

  @impl true
  def init(%{name: registry_name, repo: repo}) do
    {:ok, %{name: to_string(registry_name), repo: repo, keys: %{}}}
  end

  @type key :: atom | String.t()

  @doc false
  @spec whereis_name({GenServer.server(), key}) :: pid | :undefined
  def whereis_name({registry, key}) do
    GenServer.call(registry, {:whereis_name, key})
  end

  @doc false
  @spec register_name({GenServer.server(), key}, pid) :: :yes | :no
  def register_name({registry, key}, pid) do
    GenServer.call(registry, {:register_name, key, pid})
  end

  @doc false
  @spec unregister_name({GenServer.server(), key}) :: :ok
  def unregister_name({registry, key}) do
    GenServer.call(registry, {:unregister_name, key})
  end

  @doc false
  @spec send({GenServer.server(), key}, message) :: message when message: any()
  def send({registry, key}, msg) do
    case whereis_name({registry, key}) do
      :undefined -> :erlang.error(:badarg, [{registry, key}, msg])
      pid -> Kernel.send(pid, msg)
    end
  end

  @doc """
  Demonitors the monitor identified by the given `key`.

  The function `register_name/2` monitors the given process for
  unregistering the process when it dies. This function demonitors
  its monitor.
  """
  @spec demonitor({GenServer.server(), key}) :: boolean()
  def demonitor({registry, key}) do
    GenServer.call(registry, {:demonitor, key})
  end

  @spec process_alive?(Pid.t()) :: {:ok, node, pid} | {:dead, node, pid} | :nodedown
        when node: atom
  defp process_alive?(%Pid{node: node_bin, pid: pid_bin}) do
    node = String.to_atom(node_bin)
    pid = :erlang.binary_to_term(pid_bin)

    case :rpc.call(node, Process, :alive?, [pid]) do
      {:badrpc, :nodedown} ->
        :nodedown

      true ->
        {:ok, node, pid}

      false ->
        {:dead, node, pid}
    end
  end

  @impl true
  def handle_call({:whereis_name, key}, _from, %{name: registry_name, repo: repo} = state) do
    with %Name{id: name_id} <- repo.get_by(Name, name: registry_name),
         %Pid{} = process <- repo.get_by(Pid, name_id: name_id, key: to_string(key)),
         {:ok, _node, pid} <- process_alive?(process) do
      {:reply, pid, state}
    else
      _ ->
        {:reply, :undefined, state}
    end
  end

  def handle_call({:demonitor, key}, _from, %{keys: keys} = state) do
    ref =
      keys
      |> Enum.find_value(fn
        {ref, ^key} -> ref
        _ -> nil
      end)

    if ref do
      {:reply, Process.demonitor(ref), state}
    else
      {:reply, false, state}
    end
  end

  @impl true
  def handle_call(
        {:register_name, key, pid},
        _from,
        %{name: registry_name, repo: repo, keys: keys} = state
      ) do
    # How to insert a name if not exists.
    #
    #   1. Try to INSERT a new record and do nothing if already exists.
    #   2. SELECT the record by the name.
    #
    # If there are multiple processes to insert the same name, STEP (2) always
    # returns the correct result because one of the processes must succeed in STEP (1).
    # +1 bonus, we don't have to execute these steps in a transaction.
    {:ok, _ignored} = repo.insert(%Name{name: registry_name}, on_conflict: :nothing)
    %Name{id: name_id} = repo.get_by(Name, name: registry_name)

    # Register pid with key and name.
    #
    #   1. Try to INSERT a new record and check whether there was a conflict or not.
    #   2. If a conflict was happened, SELECT the one and check whether process is alive or not.
    #   3. If the old process was already died, replace the existing record.
    #
    # STEP 2 and 3 are needed because sometimes processes die without propagating DOWN message
    # (i. e. When a user aborts IEx shell.)
    changeset =
      %Pid{name_id: name_id}
      |> Pid.create_changeset(%{
        key: to_string(key),
        node: to_string(Node.self()),
        pid: :erlang.term_to_binary(pid)
      })

    repo.insert(changeset)
    |> case do
      {:ok, _pid} ->
        # Monitor the registered process to make it possible to DELETE the row in
        # the database when the process is stopped/crashed.
        ref = Process.monitor(pid)
        keys = Map.put(keys, ref, key)
        {:reply, :yes, %{state | keys: keys}}

      {:error, %Ecto.Changeset{errors: errors}} ->
        # must be conflict error
        unless Enum.any?(errors, &match?({:key, {"has already been taken", _}}, &1)) do
          raise "Unexpected Ecto error occurred: #{inspect(errors)}"
        end

        repo.transaction(fn ->
          Pid
          |> where(name_id: ^name_id, key: ^to_string(key))
          |> lock("FOR UPDATE")
          |> repo.one()
          |> case do
            nil ->
              # another process already deleted the row, retry INSERT
              repo.insert(changeset)

            %Pid{} = process ->
              case process_alive?(process) do
                {:ok, _node, _pid} ->
                  nil

                _ ->
                  repo.insert!(changeset,
                    on_conflict: {:replace, [:node, :pid]},
                    conflict_target: [:key, :name_id]
                  )
              end
          end
        end)
        |> case do
          {:ok, %Pid{}} ->
            # Monitor the registered process to make it possible to DELETE the row in
            # the database when the process is stopped/crashed.
            ref = Process.monitor(pid)
            keys = Map.put(keys, ref, key)
            {:reply, :yes, %{state | keys: keys}}

          _ ->
            {:reply, :no, state}
        end
    end
  end

  @impl true
  def handle_call({:unregister_name, key}, _from, %{name: registry_name, repo: repo} = state) do
    with %Name{id: name_id} <- repo.get_by(Name, name: registry_name),
         %Pid{} = pid <- repo.get_by(Pid, name_id: name_id, key: to_string(key)) do
      repo.delete!(pid)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, object, _reason}, %{keys: keys} = state) do
    state =
      case Map.fetch(keys, ref) do
        {:ok, key} ->
          {:reply, :ok, state} = handle_call({:unregister_name, key}, self(), state)
          %{state | keys: Map.delete(keys, ref)}

        :error ->
          Logger.warn(
            "Unknown process #{inspect(object)} DOWN message received for reference #{
              inspect(ref)
            }"
          )

          state
      end

    {:noreply, state}
  end
end
