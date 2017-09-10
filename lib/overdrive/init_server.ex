defmodule Overdrive.InitServer do
  require Logger
  alias Overdrive.Init
  alias Overdrive.ActorServer

  def start_link do
    Agent.start_link(fn -> init_model() end, name: __MODULE__)
  end

  def init_model do
    %{lobby: []}
  end

  def get(room) do
    Agent.get(__MODULE__, fn(state) ->
      state[room]
    end)
  end

  def set(room, inits) do
    Agent.update(__MODULE__,
      fn state ->
        Map.put(state, room, inits)
      end)
  end

  def initialise(room) do
    # get players for both sides in <room>, merge the lists
    # grab name and initBase for everything in that merged list
    # then add 1d6 to all of it
    actors = ActorServer.get(room, :players) ++ Enum.filter(ActorServer.get(room, :enemies), fn(actor) -> actor.visible end)
    inits = Enum.map(actors, fn(actor) ->
      %Init{name: actor.name, uuid: actor.uuid, idx: (actor.initBase + Enum.random(1..6))}
    end)
      |> Enum.sort(fn(a, b) ->
        a.idx <= b.idx
    end)
      |> Enum.with_index
      |> Enum.map(fn({init, idx}) ->
        %Init{name: init.name, idx: idx, uuid: init.uuid}
    end)
    set(room, inits)
  end

  def clear(room) do
    set(room, [])
  end

  def remove_init(room, uuid) do
    curr = get(room)
    new_list =
      curr
      |> Enum.reject(fn(init) -> init.uuid == uuid end)
    set(room, new_list)
  end

  def add_init(room, uuid, name) do
    curr = get(room)
    new_list = if (Enum.count curr) > 0 do
      curr ++ [%Init{name: name, idx: Enum.count(curr), uuid: uuid}]
    else
      []
    end
    set(room, new_list)
  end

  def toggle(room, uuid) do
    actor = ActorServer.get_actor_by_uuid(room, uuid)
    side = ActorServer.get_side_by_uuid(room, uuid)
    if actor.visible do
      # already visible, so we want to remove it from the init list and set visibility to false
      remove_init(room, uuid)
      ActorServer.set_visibility(room, side, uuid, false)
    else
      # invisible, so we want to add it to the bottom of the init list and set visibility to true
      add_init(room, uuid, actor.name)
      ActorServer.set_visibility(room, side, uuid, true)
    end
  end

  def update_name(room, uuid, name) do
    curr = get(room)
    if Enum.count(curr) > 0 do
      old = Enum.find(curr, fn(init) -> init.uuid == uuid end)
      old_index = Enum.find_index(curr, fn(init) -> init.uuid == uuid end)
      new_list =
        curr
        |> List.replace_at(old_index, %Init{idx: old.idx, name: name, uuid: old.uuid})
      set(room, new_list)
    end
  end

  def increment_at(room, idx) do
    if idx > 0 do
      curr = get(room)
      dest_idx = idx - 1
      swap = Enum.at curr, dest_idx
      from = Enum.at curr, idx
      new_list =
        curr
        |> List.replace_at(dest_idx, %Init{idx: dest_idx, name: from.name, uuid: from.uuid})
        |> List.replace_at(idx, %Init{idx: idx, name: swap.name, uuid: swap.uuid})
      set(room, new_list)
    end
  end

  def decrement_at(room, idx) do
    curr = get(room)
    if idx < List.last(curr).idx do
      dest_idx = idx + 1
      swap = Enum.at curr, dest_idx
      from = Enum.at curr, idx
      new_list =
        curr
        |> List.replace_at(dest_idx, %Init{idx: dest_idx, name: from.name})
        |> List.replace_at(idx, %Init{idx: idx, name: swap.name})
      set(room, new_list)
    end
  end

end
