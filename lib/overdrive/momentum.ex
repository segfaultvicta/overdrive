defmodule Overdrive.Momentum do
  @derive [Poison.Encoder]
  defstruct [:element, :strength, :actor]
end
