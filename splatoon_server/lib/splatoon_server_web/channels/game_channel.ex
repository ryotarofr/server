defmodule SplatoonServerWeb.GameChannel do
  use SplatoonServerWeb, :channel
  alias SplatoonServer.{GameServer, GameSupervisor}
  alias Phoenix.PubSub

  @impl true
  def join("game:" <> game_id, %{"team" => team}, socket) do
    player_id = socket.assigns.player_id
    
    # ゲームサーバーが存在しない場合は作成
    case GameSupervisor.start_game(game_id) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
    
    case GameServer.join_game(game_id, player_id, String.to_atom(team)) do
      :ok ->
        # ゲーム状態の更新を購読
        PubSub.subscribe(SplatoonServer.PubSub, "game:#{game_id}")
        PubSub.subscribe(SplatoonServer.PubSub, "game:updates")
        
        socket = socket
                |> assign(:game_id, game_id)
                |> assign(:team, String.to_atom(team))
        
        # 現在のゲーム状態を送信
        game_state = GameServer.get_game_state(game_id)
        push(socket, "game_state", format_game_state(game_state))
        
        {:ok, socket}
      
      error ->
        {:error, %{reason: "failed to join game: #{inspect(error)}"}}
    end
  end

  @impl true
  def handle_in("player_move", %{"position" => %{"x" => x, "y" => y}}, socket) do
    game_id = socket.assigns.game_id
    player_id = socket.assigns.player_id
    
    GameServer.update_player_position(game_id, player_id, {x, y})
    
    {:noreply, socket}
  end

  @impl true
  def handle_in("player_shoot", %{"direction" => %{"x" => x, "y" => y}}, socket) do
    game_id = socket.assigns.game_id
    player_id = socket.assigns.player_id
    
    GameServer.shoot(game_id, player_id, {x, y})
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_state, game_state}, socket) do
    push(socket, "game_state", format_game_state(game_state))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_update, player_id, position}, socket) do
    push(socket, "player_update", %{
      player_id: player_id,
      position: %{x: elem(position, 0), y: elem(position, 1)}
    })
    {:noreply, socket}
  end

  @impl true
  def handle_info({:paint_update, painted_areas}, socket) do
    formatted_areas = 
      painted_areas
      |> Enum.map(fn {{x, y}, team} -> 
        %{position: %{x: x, y: y}, team: team}
      end)
    
    push(socket, "paint_update", %{painted_areas: formatted_areas})
    {:noreply, socket}
  end

  defp format_game_state(game_state) do
    %{
      players: format_players(game_state.players),
      painted_tiles: format_painted_tiles(game_state.painted_tiles),
      game_started: game_state.game_started
    }
  end

  defp format_players(players) do
    players
    |> Enum.map(fn {_id, player} ->
      %{
        id: player.id,
        position: %{x: elem(player.position, 0), y: elem(player.position, 1)},
        team: player.team,
        health: player.health
      }
    end)
  end

  defp format_painted_tiles(painted_tiles) do
    painted_tiles
    |> Enum.map(fn {{x, y}, team} ->
      %{position: %{x: x, y: y}, team: team}
    end)
  end
end