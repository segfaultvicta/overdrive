defmodule Overdrive.ActorServer do
  require Logger
  alias Overdrive.Actor
  alias Overdrive.Status

  def start_link do
    Agent.start_link(fn -> init_model() end, name: __MODULE__)
  end

  def init_model do
    %{lobby: %{enemies: [
      %Actor{name: "Some Fucken Robot", currHP: 50, maxHP: 100, currMP: 5, maxMP: 10, currLP: 2, maxLP: 4, currDrive: 10, maxDrive: 10, initBase: 5, row: "Back",
        statuses: [%Status{status: "Energize", duration: "Short", level: 1, meta: ""}, %Status{status: "Chill", duration: "Long", level: 2, meta: ""}]},
      %Actor{name: "Beeeees!?", currHP: 20, maxHP: 100, currMP: 10, maxMP: 10, currLP: 0, maxLP: 4, currDrive: 2, maxDrive: 10, initBase: 3, row: "Front",
        statuses: []}
      ], players: [
      %Actor{name: "Phyllis", currHP: 50, maxHP: 100, currMP: 5, maxMP: 10, currLP: 2, maxLP: 4, currDrive: 10, maxDrive: 10, initBase: 5, row: "Back",
          statuses: [%Status{status: "Shock", duration: "Short", level: 2, meta: ""}]},
      %Actor{name: "Chandrasekhar", currHP: 20, maxHP: 100, currMP: 10, maxMP: 10, currLP: 0, maxLP: 4, currDrive: 2, maxDrive: 10, initBase: 3, row: "Front",
          statuses: []}
      ]
    }}
  end

  def get(side, room) do
    Agent.get(__MODULE__, fn(state) ->
      state[room][side]
    end)
  end

end
