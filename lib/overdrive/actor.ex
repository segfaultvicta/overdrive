defmodule Overdrive.Actor do
  @derive [Poison.Encoder]
  defstruct [:uuid, :name, :currHP, :maxHP, :currMP, :maxMP, :currLP, :maxLP, :currDrive, :maxDrive, :initBase, :row, :statuses, :currAmmo, :maxAmmo, :visible]
end

defmodule Overdrive.Status do
  @derive [Poison.Encoder]
  defstruct [:status, :duration, :level, :meta]
end
