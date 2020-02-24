defmodule EctoProcessRegistry.StartOptionsTest do
  use ExUnit.Case, async: true
  doctest EctoProcessRegistry

  alias EctoProcessRegistry.{Repo}

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
