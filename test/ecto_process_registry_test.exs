defmodule EctoProcessRegistryTest do
  use ExUnit.Case, async: true
  doctest EctoProcessRegistry

  alias EctoProcessRegistry.{Repo, Pid}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "start_link" do
    test "given no :name option" do
      assert_raise ArgumentError, "expected :name option to be present", fn ->
        EctoProcessRegistry.start_link([])
      end
    end

    for not_atom_value <- [1, <<0>>, "me", {:atom_in_tuple}] do
      @tag name: not_atom_value
      test "given invalid :name option: #{inspect(not_atom_value)}", %{name: name} do
        assert_raise ArgumentError, ~r/expected :name to be an atom, got:/, fn ->
          EctoProcessRegistry.start_link(name: name)
        end
      end

      @tag repo: not_atom_value
      test "given invalid :repo option: #{inspect(not_atom_value)}", %{repo: repo} do
        assert_raise ArgumentError, ~r/expected :repo to be a Ecto.Repo module, got:/, fn ->
          EctoProcessRegistry.start_link(name: :test, repo: repo)
        end
      end
    end

    test "given no :repo option" do
      assert_raise ArgumentError, "expected :repo option to be present", fn ->
        EctoProcessRegistry.start_link(name: :test)
      end
    end

    test "given name option" do
      assert {:ok, pid} = EctoProcessRegistry.start_link(name: :foo, repo: Repo)
      assert is_pid(pid)
    end
  end

  describe "name registration" do
    setup context do
      name = context[:registry_name] || :name_registry
      registry = start_supervised!({EctoProcessRegistry, name: name, repo: Repo})
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), registry)
      {:ok, %{registry: registry}}
    end

    @tag registry_name: EctoProcessRegistry.ViaTest
    test "using in :via", %{registry_name: registry_name} do
      name = {:via, EctoProcessRegistry, {registry_name, "agent"}}

      assert {:ok, pid} = Agent.start_link(fn -> 0 end, name: name)
      assert Agent.get(name, & &1) == 0
      Agent.update(name, &(&1 + 1))
      assert Agent.get(name, & &1) == 1
      assert Agent.stop(pid) == :ok

      # Process terminated
      assert EctoProcessRegistry.whereis_name({registry_name, "agent"}) == :undefined
      refute Repo.get_by(Pid, key: "agent")
    end

    test "register_name", %{registry: registry} do
      assert EctoProcessRegistry.register_name({registry, "my pid"}, self()) == :yes
      assert EctoProcessRegistry.whereis_name({registry, "my pid"}) == self()
      # already registered
      assert EctoProcessRegistry.register_name({registry, "my pid"}, self()) == :no
    end

    test "register already died process", %{registry: registry} do
      pid = :erlang.list_to_pid('<0.104.0>')
      refute Process.alive?(pid)
      assert EctoProcessRegistry.register_name({registry, "my pid"}, pid) == :yes
      assert EctoProcessRegistry.whereis_name({registry, "my pid"}) == :undefined

      # Users can register a new process if the old one already died.
      assert EctoProcessRegistry.register_name({registry, "my pid"}, self()) == :yes
      assert EctoProcessRegistry.whereis_name({registry, "my pid"}) == self()
    end

    test "demonitor -> kill -> register", %{registry: registry} do
      assert {:ok, agent} = Agent.start(fn -> 0 end)

      assert EctoProcessRegistry.register_name({registry, "agent"}, agent) == :yes
      assert EctoProcessRegistry.demonitor({registry, "agent"})

      # kill process
      assert Process.exit(agent, :kill)
      refute Process.alive?(agent)
      Process.sleep(50)
      assert Repo.get_by(Pid, key: "agent"), "the record should exist"

      # Users can register a new process if the old one died even if
      # the record exists.
      assert EctoProcessRegistry.register_name({registry, "agent"}, self()) == :yes
      assert EctoProcessRegistry.whereis_name({registry, "agent"}) == self()
    end
  end
end
