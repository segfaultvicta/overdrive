defmodule Overdrive.Actor do
  @derive [Poison.Encoder]
  defstruct [:uuid, :name, :currHP, :maxHP, :currMP, :maxMP, :currLP, :maxLP, :currDrive, :maxDrive, :initBase, :row, :statuses]
end

defmodule Overdrive.Status do
  @derive [Poison.Encoder]
  defstruct [:status, :duration, :level, :meta]
end
