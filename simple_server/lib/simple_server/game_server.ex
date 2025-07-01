defmodule SimpleServer.GameServer do
  use GenServer

  defmodule State do
    defstruct [
      :game_id,
      :players,
      :painted_tiles,
      :clients
    ]
  end

  defmodule Player do
    defstruct [
      :id,
      :position,
      :team,
      :health
    ]
  end

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def join_game_udp(game_id, player_id, team, client_key) do
    GenServer.call(via_tuple(game_id), {:join_game, player_id, team, client_key})
  end

  def update_player_position(game_id, player_id, position) do
    GenServer.cast(via_tuple(game_id), {:update_position, player_id, position})
  end

  def shoot(game_id, player_id, direction) do
    GenServer.cast(via_tuple(game_id), {:shoot, player_id, direction})
  end

  def remove_client(game_id, client_key) do
    GenServer.cast(via_tuple(game_id), {:remove_client, client_key})
  end

  # GenServer callbacks

  @impl true
  def init(game_id) do
    state = %State{
      game_id: game_id,
      players: %{},
      painted_tiles: %{},
      clients: []
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:join_game, player_id, team, client_key}, _from, state) do
    player = %Player{
      id: player_id,
      position: {0.0, 0.0},
      team: team,
      health: 100
    }
    
    new_players = Map.put(state.players, player_id, player)
    new_clients = [client_key | state.clients]
    new_state = %{state | players: new_players, clients: new_clients}
    
    broadcast_game_state(new_state)
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:update_position, player_id, position}, state) do
    case Map.get(state.players, player_id) do
      nil -> {:noreply, state}
      player ->
        updated_player = %{player | position: position}
        new_players = Map.put(state.players, player_id, updated_player)
        new_state = %{state | players: new_players}
        
        broadcast_player_update(new_state, player_id, position)
        
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast({:shoot, player_id, direction}, state) do
    case Map.get(state.players, player_id) do
      nil -> {:noreply, state}
      player ->
        painted_areas = calculate_paint_trajectory(player.position, direction, player.team)
        new_painted_tiles = Map.merge(state.painted_tiles, painted_areas)
        new_state = %{state | painted_tiles: new_painted_tiles}
        
        broadcast_paint_update(new_state, painted_areas)
        
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast({:remove_client, client_key}, state) do
    new_clients = List.delete(state.clients, client_key)
    new_state = %{state | clients: new_clients}
    {:noreply, new_state}
  end

  # Private functions

  defp via_tuple(game_id) do
    {:via, Registry, {SimpleServer.GameRegistry, game_id}}
  end

  defp calculate_paint_trajectory({x, y}, {dx, dy}, team) do
    steps = 10
    paint_radius = 1
    
    for step <- 1..steps,
        tile_x <- trunc(x + dx * step) - paint_radius..trunc(x + dx * step) + paint_radius,
        tile_y <- trunc(y + dy * step) - paint_radius..trunc(y + dy * step) + paint_radius,
        into: %{} do
      {{tile_x, tile_y}, team}
    end
  end

  defp broadcast_game_state(state) do
    message = %{
      type: "game_state",
      players: format_players(state.players),
      painted_tiles: format_painted_tiles(state.painted_tiles)
    }
    
    SimpleServer.UdpServer.broadcast_to_game_clients(state.game_id, message)
  end

  defp broadcast_player_update(state, player_id, position) do
    message = %{
      type: "player_update",
      player_id: player_id,
      position: %{x: elem(position, 0), y: elem(position, 1)}
    }
    
    SimpleServer.UdpServer.broadcast_to_game_clients(state.game_id, message)
  end

  defp broadcast_paint_update(state, painted_areas) do
    formatted_areas = 
      painted_areas
      |> Enum.map(fn {{x, y}, team} -> 
        %{position: %{x: x, y: y}, team: team}
      end)
    
    message = %{
      type: "paint_update",
      painted_areas: formatted_areas
    }
    
    SimpleServer.UdpServer.broadcast_to_game_clients(state.game_id, message)
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