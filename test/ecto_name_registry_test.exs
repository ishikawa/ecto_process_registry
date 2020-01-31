defmodule EctoNameRegistryTest do
  use ExUnit.Case, async: true
  doctest EctoNameRegistry

  alias EctoNameRegistry.{Repo, Pid}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "start_link" do
    test "given no :name option" do
      assert_raise ArgumentError, "expected :name option to be present", fn ->
        EctoNameRegistry.start_link([])
      end
    end

    for name <- [1, <<0>>, "me", {:atom_in_tuple}] do
      @tag name: name
      test "given invalid :name option: #{inspect(name)}", %{name: name} do
        assert_raise ArgumentError, ~r/expected :name to be an atom, got:/, fn ->
          EctoNameRegistry.start_link(name: name)
        end
      end
    end

    test "given name option" do
      assert {:ok, pid} = EctoNameRegistry.start_link(name: :foo)
      assert is_pid(pid)
    end
  end

  describe "name registration" do
    setup context do
      name = context[:registry_name] || :name_registry
      registry = start_supervised!({EctoNameRegistry, name: name})
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), registry)
      {:ok, %{registry: registry}}
    end

    @tag registry_name: EctoNameRegistry.ViaTest
    test "using in :via", %{registry_name: registry_name} do
      name = {:via, EctoNameRegistry, {registry_name, "agent"}}

      assert {:ok, pid} = Agent.start_link(fn -> 0 end, name: name)
      assert Agent.get(name, & &1) == 0
      Agent.update(name, &(&1 + 1))
      assert Agent.get(name, & &1) == 1
      assert Agent.stop(pid) == :ok

      # Process terminated
      assert EctoNameRegistry.whereis_name({registry_name, "agent"}) == :undefined
      refute Repo.get_by(Pid, key: "agent")
    end
  end
end
