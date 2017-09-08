defmodule Overdrive.MomentumServer do
  require Logger

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

  def set(room, momenta) do
    Agent.update(__MODULE__,
      fn state ->
        Map.put(state, room, momenta)
      end)
  end

  def add(room, momentum) do
    curr_momenta = get(room)
    momenta = curr_momenta ++ [momentum]
    set(room, momenta)
  end

  def remove(room, momentum) do
    curr_momenta = get(room)
    momenta = List.delete(curr_momenta, momentum)
    set(room, momenta)
  end

  def clear(room) do
    set(room, [])
  end

end
