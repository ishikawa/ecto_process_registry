defmodule EctoProcessRegistry.NameRegistrationTest do
  use ExUnit.Case, async: true

  alias EctoProcessRegistry.{Repo, Pid}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  # Start supervised EctoProcessRegistry if `:registry_name` specified in the context.
  setup context do
    name =
      with name when is_nil(name) <- context[:registry_name] do
        n = :random.uniform(1_000)
        :"ondemand_process_registry_#{n}"
      end

    registry = start_supervised!({EctoProcessRegistry, name: name, repo: Repo})
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), registry)
    {:ok, %{registry: registry, registry_name: name}}
  end

  describe "whereis_name/2" do
    test "no registration", %{registry: registry} do
      assert EctoProcessRegistry.whereis_name({registry, "my pid"}) == :undefined
    end

    test "register self", %{registry: registry} do
      EctoProcessRegistry.register_name({registry, "my pid"}, self())
      assert EctoProcessRegistry.whereis_name({registry, "my pid"}) == self()
    end
  end

  describe "register_name/2" do
    test "register name", %{registry: registry} do
      assert EctoProcessRegistry.register_name({registry, "my pid"}, self()) == :yes
      # already registered
      assert EctoProcessRegistry.register_name({registry, "my pid"}, self()) == :no
    end

    test "when name is not a pid", %{registry: registry} do
      assert_raise(FunctionClauseError, fn ->
        assert EctoProcessRegistry.register_name({registry, "my pid"}, 12345) == :yes
      end)
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
  end

  describe "demonitor/2" do
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

  describe "name registration" do
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
  end
end
