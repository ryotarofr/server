defmodule SimpleServer.WebSocketHandler do
  @behaviour :cowboy_websocket

  def init(request, _state) do
    {:cowboy_websocket, request, %{}}
  end

  def websocket_init(state) do
    {:ok, state}
  end

  def websocket_handle({:text, message}, state) do
    case Jason.decode(message) do
      {:ok, %{"type" => "join_game", "game_id" => game_id, "player_id" => player_id, "team" => team}} ->
        # ゲームサーバーが存在しない場合は作成
        case SimpleServer.GameSupervisor.start_game(game_id) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          _ -> :error
        end
        
        SimpleServer.GameServer.join_game(game_id, player_id, String.to_atom(team), self())
        new_state = Map.merge(state, %{game_id: game_id, player_id: player_id, team: team})
        {:ok, new_state}
      
      {:ok, %{"type" => "player_move", "position" => %{"x" => x, "y" => y}}} ->
        if state[:game_id] && state[:player_id] do
          SimpleServer.GameServer.update_player_position(state.game_id, state.player_id, {x, y})
        end
        {:ok, state}
      
      {:ok, %{"type" => "player_shoot", "direction" => %{"x" => x, "y" => y}}} ->
        if state[:game_id] && state[:player_id] do
          SimpleServer.GameServer.shoot(state.game_id, state.player_id, {x, y})
        end
        {:ok, state}
      
      _ ->
        {:ok, state}
    end
  end

  def websocket_info({:broadcast, message}, state) do
    {:reply, {:text, message}, state}
  end

  def websocket_info(_, state) do
    {:ok, state}
  end

  def terminate(_reason, _request, state) do
    if state[:game_id] do
      SimpleServer.GameServer.remove_websocket(state.game_id, self())
    end
    :ok
  end
end