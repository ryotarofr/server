defmodule SplatoonServer.GameServer do
  use GenServer
  alias Phoenix.PubSub

  @tick_rate 60

  defmodule State do
    defstruct [
      :game_id,
      :players,
      :painted_tiles,
      :game_started,
      :match_timer
    ]
  end

  defmodule Player do
    defstruct [
      :id,
      :position,
      :team,
      :health,
      :last_update
    ]
  end

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def join_game(game_id, player_id, team) do
    GenServer.call(via_tuple(game_id), {:join_game, player_id, team})
  end

  def update_player_position(game_id, player_id, position) do
    GenServer.cast(via_tuple(game_id), {:update_position, player_id, position})
  end

  def shoot(game_id, player_id, direction) do
    GenServer.cast(via_tuple(game_id), {:shoot, player_id, direction})
  end

  def get_game_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_game_state)
  end

  # GenServer callbacks

  @impl true
  def init(game_id) do
    schedule_tick()
    
    state = %State{
      game_id: game_id,
      players: %{},
      painted_tiles: %{},
      game_started: false,
      match_timer: 180_000  # 3分間
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:join_game, player_id, team}, _from, state) do
    player = %Player{
      id: player_id,
      position: {0.0, 0.0},
      team: team,
      health: 100,
      last_update: System.monotonic_time(:millisecond)
    }
    
    new_players = Map.put(state.players, player_id, player)
    new_state = %{state | players: new_players}
    
    broadcast_game_state(new_state)
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_game_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_position, player_id, position}, state) do
    case Map.get(state.players, player_id) do
      nil -> {:noreply, state}
      player ->
        updated_player = %{player | position: position, last_update: System.monotonic_time(:millisecond)}
        new_players = Map.put(state.players, player_id, updated_player)
        new_state = %{state | players: new_players}
        
        broadcast_player_update(player_id, position)
        
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast({:shoot, player_id, direction}, state) do
    case Map.get(state.players, player_id) do
      nil -> {:noreply, state}
      player ->
        # 弾丸の軌道を計算してペイントエリアを更新
        painted_areas = calculate_paint_trajectory(player.position, direction, player.team)
        new_painted_tiles = Map.merge(state.painted_tiles, painted_areas)
        new_state = %{state | painted_tiles: new_painted_tiles}
        
        broadcast_paint_update(painted_areas)
        
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    # ゲームの定期更新処理
    new_state = update_game_logic(state)
    broadcast_game_state(new_state)
    
    schedule_tick()
    {:noreply, new_state}
  end

  # Private functions

  defp via_tuple(game_id) do
    {:via, Registry, {SplatoonServer.GameRegistry, game_id}}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, div(1000, @tick_rate))
  end

  defp update_game_logic(state) do
    # ゲームロジックの更新
    # - プレイヤーの健康状態チェック
    # - タイマーの更新
    # - 勝利条件の確認など
    
    current_time = System.monotonic_time(:millisecond)
    
    # 非アクティブなプレイヤーを削除
    active_players = 
      state.players
      |> Enum.filter(fn {_, player} -> 
        current_time - player.last_update < 30_000  # 30秒以内
      end)
      |> Enum.into(%{})
    
    %{state | players: active_players}
  end

  defp calculate_paint_trajectory({x, y}, {dx, dy}, team) do
    # 弾丸の軌道に沿ってペイントされるタイルを計算
    steps = 10
    paint_radius = 2
    
    for step <- 1..steps,
        tile_x <- trunc(x + dx * step) - paint_radius..trunc(x + dx * step) + paint_radius,
        tile_y <- trunc(y + dy * step) - paint_radius..trunc(y + dy * step) + paint_radius,
        into: %{} do
      {{tile_x, tile_y}, team}
    end
  end

  defp broadcast_game_state(state) do
    PubSub.broadcast(SplatoonServer.PubSub, "game:#{state.game_id}", {:game_state, state})
  end

  defp broadcast_player_update(player_id, position) do
    PubSub.broadcast(SplatoonServer.PubSub, "game:updates", {:player_update, player_id, position})
  end

  defp broadcast_paint_update(painted_areas) do
    PubSub.broadcast(SplatoonServer.PubSub, "game:updates", {:paint_update, painted_areas})
  end
end