defmodule OverdriveWeb.RoomChannel do
  use OverdriveWeb, :channel
  alias Overdrive.MomentumServer
  alias Overdrive.ActorServer
  alias Overdrive.InitServer
  alias Overdrive.Actor
  alias Overdrive.Momentum
  require Logger

  def join("room:lobby", payload, socket) do
    if authorized?(payload) do
      send self(), {:momentum_update}
      send self(), {:status_update}
      send self(), {:inits_update}
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("new_momentum", %{"element" => element, "strength" => strength, "actor" => actor}, socket) do
    new_momentum = %Momentum{element: element, strength: strength, actor: actor}
    MomentumServer.add(:lobby, new_momentum)
    send self(), {:momentum_update}
    {:reply, :ok, socket}
  end

  def handle_in("remove_momentum", %{"element" => element, "strength" => strength, "actor" => actor}, socket) do
    to_remove = %Momentum{element: element, strength: strength, actor: actor}
    MomentumServer.remove(:lobby,to_remove)
    send self(), {:momentum_update}
    {:reply, :ok, socket}
  end

  def handle_in("clear_momentum", _, socket) do
    MomentumServer.clear(:lobby)
    send self(), {:momentum_update}
    {:reply, :ok, socket}
  end

  def handle_in("add_actor", %{"team" => team_string}, socket) do
    team = if team_string == "player" do :players else :enemies end
    ActorServer.add(:lobby, team)
    send self(), {:status_update}
    {:reply, :ok, socket}
  end

  def handle_in("remove_actor", %{"uuid" => uuid}, socket) do
    ActorServer.delete(:lobby, uuid)
    send self(), {:status_update}
    {:reply, :ok, socket}
  end

  def handle_in("save_actor", actor, socket) do
    team = if actor["team"] == "player" do :players else :enemies end
    to_save = %Actor{name: actor["name"], currHP: actor["currHP"], maxHP: actor["maxHP"],
                     currMP: actor["currMP"], maxMP: actor["maxMP"], currLP: actor["currLP"],
                     maxLP: actor["maxLP"], currDrive: actor["currDrive"], maxDrive: actor["maxDrive"],
                     initBase: actor["initBase"], row: actor["row"], statuses: actor["statuses"], uuid: actor["uuid"],
                     currAmmo: actor["currAmmo"], maxAmmo: actor["maxAmmo"]}
    ActorServer.save(:lobby, team, actor["uuid"], to_save)
    send self(), {:status_update}
    {:reply, :ok, socket}
  end

  def handle_in("initialise_init", _, socket) do
    InitServer.initialise(:lobby)
    send self(), {:inits_update}
    {:reply, :ok, socket}
  end

  def handle_in("clear_init", _, socket) do
    InitServer.clear(:lobby)
    send self(), {:inits_update}
    {:reply, :ok, socket}
  end

  def handle_in("increment_init", %{"idx" => idx}, socket) do
    InitServer.increment_at(:lobby, idx)
    send self(), {:inits_update}
    {:reply, :ok, socket}
  end

  def handle_in("decrement_init", %{"idx" => idx}, socket) do
    InitServer.decrement_at(:lobby, idx)
    send self(), {:inits_update}
    {:reply, :ok, socket}
  end

  def handle_info({:momentum_update}, socket) do
    broadcast!(socket, "momentum_update", %{"momenta": MomentumServer.get(:lobby)})
    {:noreply, socket}
  end

  def handle_info({:status_update}, socket) do
    broadcast!(socket, "status_update", %{"players": ActorServer.get(:lobby, :players), "enemies": ActorServer.get(:lobby, :enemies)})
    {:noreply, socket}
  end

  def handle_info({:inits_update}, socket) do
    broadcast!(socket, "inits_update", %{"inits": InitServer.get(:lobby)})
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
