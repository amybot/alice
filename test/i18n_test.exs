defmodule I18nTest do
  use ExUnit.Case
  doctest Alice.I18n

  setup do
    Application.start(:fast_yaml)
    {:ok, server} = Alice.I18n.start_link []
    {:ok, server: server}
  end

  test "Base translation works", %{server: pid} do
    tln = GenServer.call pid, {:translate, "en", "test"}
    assert tln == "test"
  end

  test "Wrong locale returns error", %{server: pid} do
    tln = GenServer.call pid, {:translate, "non-real-locale", "doesnt-matter"}
    assert tln == "<unknown translation>"
  end

  test "Invalid key returns error", %{server: pid} do
    tln = GenServer.call pid, {:translate, "en", "key-that-isnt-real"}
    assert tln == "<unknown translation>"
  end

  test "Block translation works", %{server: pid} do
    one = GenServer.call pid, {:translate, "en", "test-block.one"}
    assert one == "1"
    two = GenServer.call pid, {:translate, "en", "test-block.test.two"}
    assert two == "2"
  end
end