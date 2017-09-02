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

    actors = ActorServer.get(room, :players) ++ ActorServer.get(room, :enemies)
    inits = Enum.map(actors, fn(actor) ->
      %Init{name: actor.name, idx: (actor.initBase + Enum.random(1..6))}
    end)
      |> Enum.sort(fn(a, b) ->
        a.idx <= b.idx
    end)
      |> Enum.with_index
      |> Enum.map(fn({init, idx}) ->
        %Init{name: init.name, idx: idx}
    end)
    set(room, inits)
  end

  def clear(room) do
    set(room, [])
  end

  def increment_at(room, idx) do
    if idx > 0 do
      curr = get(room)
      dest_idx = idx - 1
      swap = Enum.at curr, dest_idx
      from = Enum.at curr, idx
      new_list =
        curr
        |> List.replace_at(dest_idx, %Init{idx: dest_idx, name: from.name})
        |> List.replace_at(idx, %Init{idx: idx, name: swap.name})
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
