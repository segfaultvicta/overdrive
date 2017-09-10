defmodule Overdrive.ActorServer do
  require Logger
  alias Overdrive.Actor
  alias Overdrive.Status
  alias Overdrive.InitServer

  def start_link do
    Agent.start_link(fn -> init_model() end, name: __MODULE__)
  end

  def init_model do
    %{lobby: %{enemies: [
      %Actor{visible: false, uuid: UUID.uuid4, name: "Some Fucken Robot", currHP: 50, maxHP: 100, currMP: 5, maxMP: 10, currLP: 2, maxLP: 4, currDrive: 10, maxDrive: 10, initBase: 5, row: "Back",
        statuses: [%Status{status: "Energize", duration: "Short", level: 1, meta: ""}, %Status{status: "Chill", duration: "Long", level: 2, meta: ""}], currAmmo: 1, maxAmmo: 2},
      %Actor{visible: true, uuid: UUID.uuid4, name: "Beeeees!?", currHP: 20, maxHP: 100, currMP: 10, maxMP: 10, currLP: 0, maxLP: 4, currDrive: 2, maxDrive: 10, initBase: 3, row: "Front",
        statuses: [], currAmmo: 2, maxAmmo: 2}
      ], players: [
      %Actor{visible: true, uuid: UUID.uuid4, name: "Phyllis", currHP: 50, maxHP: 100, currMP: 5, maxMP: 10, currLP: 2, maxLP: 4, currDrive: 10, maxDrive: 10, initBase: 5, row: "Back",
          statuses: [%Status{status: "Shock", duration: "Short", level: 2, meta: ""}], currAmmo: 2, maxAmmo: 3},
      %Actor{visible: true, uuid: UUID.uuid4, name: "Chandrasekhar", currHP: 20, maxHP: 100, currMP: 10, maxMP: 10, currLP: 0, maxLP: 4, currDrive: 2, maxDrive: 10, initBase: 3, row: "Front",
          statuses: [], currAmmo: 5, maxAmmo: 5}
      ]
    }}
  end

  def get(room, :all) do
    get(room, :enemies) ++ get(room, :players)
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

  def get_side_by_uuid(room, uuid) do
    players = get(room, :players)
    if Enum.any?(players, fn(actor) -> actor.uuid == uuid end) do
      :players
    else
      :enemies
    end
  end

  def get_actor_by_uuid(room, uuid) do
    all = get(room, :players) ++ get(room, :enemies)
    Enum.find(all, fn(actor) -> actor.uuid == uuid end)
  end

  def get_actors(room, side) do
    get_actors(room, side, :visible, true)
  end

  def get_actors(room, side, field, criterion) do
    get(room, side)
    |> Enum.filter(fn(actor) -> (
      (Map.get(actor, field) == criterion) && actor.visible
    ) end)
  end

  def delete(room, uuid) do
    delete(room, get_side_by_uuid(room, uuid), uuid)
  end

  def delete(room, side, uuid) do
    curr = get(room, side)
    other_side = get_other_side(room, side)
    other_side_name = get_other_side_name(side)
    new_curr = Enum.reject(curr, fn(actor) -> actor.uuid == uuid end)
    new_map = %{}
    |> Map.put(side, new_curr)
    |> Map.put(other_side_name, other_side)

    Agent.update(__MODULE__,
      fn state ->
        Map.put(state, room, new_map)
      end)

    InitServer.remove_init(room, uuid)
  end

  def set_visibility(room, side, uuid, visibility) do
    curr_side = get(room, side)
    other_side = get_other_side(room, side)
    other_side_name = get_other_side_name(side)

    update_index = Enum.find_index(curr_side, fn(actor) -> actor.uuid == uuid end)
    new_curr_side = List.update_at(curr_side, update_index, fn(actor) -> %{actor | visible: visibility} end)
    new_map = %{}
      |> Map.put(side, new_curr_side)
      |> Map.put(other_side_name, other_side)

    Agent.update(__MODULE__,
        fn state ->
          Map.put(state, room, new_map)
        end)
  end

  def save(room, side, uuid, actor) do
    curr_side = get(room, side)
    other_side = get_other_side(room, side)
    other_side_name = get_other_side_name(side)
    replace_index = Enum.find_index(curr_side, fn(actor) -> actor.uuid == uuid end)
    new_curr_side = List.replace_at(curr_side, replace_index, actor)
    new_map = %{}
    |> Map.put(side, new_curr_side)
    |> Map.put(other_side_name, other_side)

    Agent.update(__MODULE__,
      fn state ->
        Map.put(state, room, new_map)
      end)

    InitServer.update_name(room, uuid, actor.name)
  end

  def add(room, side) do
    curr_side = get(room, side)
    other_side = get_other_side(room, side)
    other_side_name = get_other_side_name(side)
    new_uuid = UUID.uuid4()
    new_curr_side = curr_side ++ [%Actor{visible: (side == :players), uuid: new_uuid, name: "???", currHP: 0, maxHP: 0, currMP: 0, maxMP: 0, currLP: 0, maxLP: 0, currDrive: 0, maxDrive: 0, initBase: 0, row: "Front", statuses: [], currAmmo: 0, maxAmmo: 0}]
    new_map = %{}
    |> Map.put(side, new_curr_side)
    |> Map.put(other_side_name, other_side)

    Agent.update(__MODULE__,
      fn state ->
        Map.put(state, room, new_map)
      end)
  end

  def duplicate(room, uuid) do
    side = get_side_by_uuid(room, uuid)
    from = get_actor_by_uuid(room, uuid)

    curr_side = get(room, side)
    other_side = get_other_side(room, side)
    other_side_name = get_other_side_name(side)

    new_uuid = UUID.uuid4()
    new_curr_side = curr_side ++ [%{from | uuid: new_uuid, visible: false}]
    new_map = %{}
    |> Map.put(side, new_curr_side)
    |> Map.put(other_side_name, other_side)

    Agent.update(__MODULE__,
      fn state ->
        Map.put(state, room, new_map)
      end)
  end

end
