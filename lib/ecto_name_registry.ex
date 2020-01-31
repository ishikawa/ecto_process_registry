defmodule EctoNameRegistry do
  @moduledoc """
  Documentation for EctoNameRegistry.
  """
  use GenServer

  alias EctoNameRegistry.{Repo, Name, Pid}

  require Logger

  @spec start_link([option] | GenServer.options()) :: GenServer.on_start()
        when option: {:name, atom}
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

    GenServer.start_link(__MODULE__, %{name: name}, options)
  end

  @impl true
  def init(%{name: registry_name}) do
    {:ok, %{name: to_string(registry_name), keys: %{}}}
  end

  @type key :: atom | String.t()

  @doc false
  @spec whereis_name({GenServer.server(), key}) :: pid | :undefined
  def whereis_name({registry, key}), do: whereis_name(registry, key)

  defp whereis_name(registry, key) do
    GenServer.call(registry, {:whereis_name, key})
  end

  @doc false
  @spec register_name({GenServer.server(), key}, pid) :: :yes | :no
  def register_name({registry, key}, pid), do: register_name(registry, key, pid)

  defp register_name(registry, key, pid) do
    GenServer.call(registry, {:register_name, key, pid})
  end

  @doc false
  def unregister_name({registry, key}) do
    GenServer.call(registry, {:unregister_name, key})
  end

  @impl true
  def handle_call({:whereis_name, key}, _from, %{name: registry_name} = state) do
    with %Name{id: name_id} <- Repo.get_by(Name, name: registry_name),
         %Pid{pid: pid_bin} <- Repo.get_by(Pid, name_id: name_id, key: to_string(key)),
         pid = :erlang.binary_to_term(pid_bin),
         true <- Process.alive?(pid) do
      {:reply, pid, state}
    else
      _ ->
        {:reply, :undefined, state}
    end
  end

  @impl true
  def handle_call({:register_name, key, pid}, _from, %{name: registry_name, keys: keys} = state) do
    %Name{id: name_id} =
      with nil <- Repo.get_by(Name, name: registry_name) do
        Repo.insert!(%Name{name: registry_name})
      end

    %Pid{name_id: name_id, key: to_string(key), pid: :erlang.term_to_binary(pid)}
    |> Repo.insert()
    |> case do
      {:ok, _pid} ->
        # Monitor the registered process to make it possible to DELETE the row in
        # the database when the process is stopped/crashed.
        ref = Process.monitor(pid)
        keys = Map.put(keys, ref, key)
        {:reply, :yes, %{state | keys: keys}}

      {:error, changeset} ->
        IO.inspect(changeset)
        {:reply, :no, state}
    end
  end

  @impl true
  def handle_call({:unregister_name, key}, _from, %{name: registry_name} = state) do
    with %Name{id: name_id} <- Repo.get_by(Name, name: registry_name),
         %Pid{} = pid <- Repo.get_by(Pid, name_id: name_id, key: to_string(key)) do
      Repo.delete!(pid)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, object, reason}, %{keys: keys} = state) do
    IO.puts("{:DOWN, #{inspect(ref)}, :process, #{inspect(object)}, #{inspect(reason)}}")

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

  def handle_info(msg, state) do
    IO.puts("Unknown message received: #{inspect(msg)}")
    {:noreply, state}
  end
end
