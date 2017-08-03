defmodule OverdriveWeb.PageController do
  use OverdriveWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
