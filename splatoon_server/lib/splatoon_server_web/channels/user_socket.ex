defmodule SplatoonServerWeb.UserSocket do
  use Phoenix.Socket

  channel "game:*", SplatoonServerWeb.GameChannel

  @impl true
  def connect(params, socket, _connect_info) do
    player_id = params["player_id"] || UUID.uuid4()
    socket = assign(socket, :player_id, player_id)
    {:ok, socket}
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.player_id}"
end