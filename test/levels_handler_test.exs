defmodule LevelsHandlerTest do
  use ExUnit.Case
  doctest Alice.LevelsHandler

  test "level_to_xp works" do
    xp = Alice.LevelsHandler.level_to_xp 0
    assert xp == 0
    xp = Alice.LevelsHandler.level_to_xp 1
    assert xp == 100
    xp = Alice.LevelsHandler.level_to_xp 2
    assert xp == 220
  end

  test "full_level_to_xp works" do
    xp = Alice.LevelsHandler.full_level_to_xp 0
    assert xp == 0
    xp = Alice.LevelsHandler.full_level_to_xp 1
    assert xp == 100
    xp = Alice.LevelsHandler.full_level_to_xp 2
    assert xp == 320
  end

  test "xp_to_level works" do
    level0 = Alice.LevelsHandler.xp_to_level 0
    assert level0 == 0
    level1 = Alice.LevelsHandler.xp_to_level 100
    assert level1 == 1
    level2 = Alice.LevelsHandler.xp_to_level 320
    assert level2 == 2
  end
end