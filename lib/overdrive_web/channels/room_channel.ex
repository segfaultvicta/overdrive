defmodule OverdriveWeb.RoomChannel do
  use OverdriveWeb, :channel
  alias Overdrive.MomentumServer
  alias Overdrive.Momentum
  require Logger

  def join("room:lobby", payload, socket) do
    if authorized?(payload) do
      send self(), {:momentum_update}
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

  def handle_in("new_momentum", %{"element" => element, "strength" => strength}, socket) do
    new_momentum = %Momentum{element: element, strength: strength}
    MomentumServer.add(:lobby, new_momentum)
    send self(), {:momentum_update}
    {:reply, :ok, socket}
  end

  def handle_in("remove_momentum", %{"element" => element, "strength" => strength}, socket) do
    to_remove = %Momentum{element: element, strength: strength}
    MomentumServer.remove(:lobby,to_remove)
    send self(), {:momentum_update}
    {:reply, :ok, socket}
  end

  def handle_in("clear_momentum", _, socket) do
    MomentumServer.clear(:lobby)
    send self(), {:momentum_update}
    {:reply, :ok, socket}
  end

  def handle_info({:momentum_update}, socket) do
    broadcast!(socket, "momentum_update", %{"momenta": MomentumServer.get(:lobby)})
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
