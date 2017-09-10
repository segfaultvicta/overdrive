defmodule Overdrive.Init do
  @derive [Poison.Encoder]
  defstruct [:name, :idx, :uuid]
end
