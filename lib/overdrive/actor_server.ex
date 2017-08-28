defmodule Overdrive.ActorServer do
  require Logger
  alias Overdrive.Actor
  alias Overdrive.Status

  def start_link do
    Agent.start_link(fn -> init_model() end, name: __MODULE__)
  end

  def init_model do
    %{lobby: %{enemies: [
      %Actor{uuid: UUID.uuid4, name: "Some Fucken Robot", currHP: 50, maxHP: 100, currMP: 5, maxMP: 10, currLP: 2, maxLP: 4, currDrive: 10, maxDrive: 10, initBase: 5, row: "Back",
        statuses: [%Status{status: "Energize", duration: "Short", level: 1, meta: ""}, %Status{status: "Chill", duration: "Long", level: 2, meta: ""}]},
      %Actor{uuid: UUID.uuid4, name: "Beeeees!?", currHP: 20, maxHP: 100, currMP: 10, maxMP: 10, currLP: 0, maxLP: 4, currDrive: 2, maxDrive: 10, initBase: 3, row: "Front",
        statuses: []}
      ], players: [
      %Actor{uuid: UUID.uuid4, name: "Phyllis", currHP: 50, maxHP: 100, currMP: 5, maxMP: 10, currLP: 2, maxLP: 4, currDrive: 10, maxDrive: 10, initBase: 5, row: "Back",
          statuses: [%Status{status: "Shock", duration: "Short", level: 2, meta: ""}]},
      %Actor{uuid: UUID.uuid4, name: "Chandrasekhar", currHP: 20, maxHP: 100, currMP: 10, maxMP: 10, currLP: 0, maxLP: 4, currDrive: 2, maxDrive: 10, initBase: 3, row: "Front",
          statuses: []}
      ]
    }}
  end

  def get(room, side) do
    Agent.get(__MODULE__, fn(state) ->
      state[room][side]
    end)
  end

  def get_other_side(room, side) do
    case side do
      :players ->
        get(room, :enemies)
      :enemies ->
        get(room, :players)
    end
  end

  def get_other_side_name(side) do
    case side do
      :players ->
        :enemies
      :enemies ->
        :players
    end
  end

  def save_actor(room, side, uuid, actor) do
    curr_side = get(room, side)
    other_side = get_other_side(room, side)
    other_side_name = get_other_side_name(side)
    replace_index = Enum.find_index(curr_side, fn(actor) -> actor.uuid == uuid end)
    new_curr_side = List.replace_at(curr_side, replace_index, actor)
    new_map = %{}
    |> Map.put(side, new_curr_side)
    |> Map.put(other_side_name, other_side)

    # OKAY WHAT I NEED TO DO HERE IS
    # When I add_actor, I give it some kind of randomly generated GUID
    # and then updates to actor rely on the existence of that hidden GUID
    # so I don't have to index based on actor name!

    Agent.update(__MODULE__,
      fn state ->
        Map.put(state, room, new_map)
      end)
  end

  def add_actor(room, side) do
    curr_side = get(room, side)
    other_side = get_other_side(room, side)
    other_side_name = get_other_side_name(side)
    new_curr_side = curr_side ++ [%Actor{uuid: UUID.uuid4(), name: "???", currHP: 0, maxHP: 0, currMP: 0, maxMP: 0, currLP: 0, maxLP: 0, currDrive: 0, maxDrive: 0, initBase: 0, row: "Front", statuses: []}]
    new_map = %{}
    |> Map.put(side, new_curr_side)
    |> Map.put(other_side_name, other_side)

    Agent.update(__MODULE__,
      fn state ->
        Map.put(state, room, new_map)
      end)
  end

end
