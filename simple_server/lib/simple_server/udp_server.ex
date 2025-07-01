defmodule SimpleServer.UdpServer do
  use GenServer
  require Logger

  @port 8083

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, socket} = :gen_udp.open(@port, [:binary, active: true])
    Logger.info("UDP Server started on port #{@port}")
    
    # クリーンアップタイマーを開始
    Process.send_after(self(), :cleanup_clients, 30_000)
    
    {:ok, %{socket: socket, clients: %{}}}
  end

  def handle_info({:udp, socket, ip, port, data}, state) do
    case Jason.decode(data) do
      {:ok, message} ->
        handle_message(message, ip, port, state)
      {:error, _} ->
        Logger.warn("Invalid JSON received from #{inspect(ip)}:#{port}")
        {:noreply, state}
    end
  end

  defp handle_message(%{"type" => "join_game", "game_id" => game_id, "player_id" => player_id, "team" => team}, ip, port, state) do
    client_key = {ip, port}
    
    # ゲームサーバーが存在しない場合は作成
    case SimpleServer.GameSupervisor.start_game(game_id) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      _ -> :error
    end
    
    # クライアント情報を保存
    client_info = %{
      player_id: player_id,
      game_id: game_id,
      team: team,
      last_seen: System.monotonic_time(:millisecond)
    }
    
    new_clients = Map.put(state.clients, client_key, client_info)
    new_state = %{state | clients: new_clients}
    
    # ゲームサーバーに参加
    SimpleServer.GameServer.join_game_udp(game_id, player_id, String.to_atom(team), client_key)
    
    # 接続確認メッセージを送信
    response = Jason.encode!(%{type: "connected", player_id: player_id})
    :gen_udp.send(state.socket, ip, port, response)
    
    Logger.info("Player #{player_id} joined game #{game_id} from #{inspect(ip)}:#{port}")
    {:noreply, new_state}
  end

  defp handle_message(%{"type" => "player_move", "position" => %{"x" => x, "y" => y}}, ip, port, state) do
    client_key = {ip, port}
    
    case Map.get(state.clients, client_key) do
      nil ->
        Logger.warn("Unknown client #{inspect(ip)}:#{port} tried to move")
        {:noreply, state}
      
      client_info ->
        # 最後に見た時間を更新
        updated_client = %{client_info | last_seen: System.monotonic_time(:millisecond)}
        new_clients = Map.put(state.clients, client_key, updated_client)
        new_state = %{state | clients: new_clients}
        
        # ゲームサーバーに位置更新を送信
        SimpleServer.GameServer.update_player_position(client_info.game_id, client_info.player_id, {x, y})
        
        {:noreply, new_state}
    end
  end

  defp handle_message(%{"type" => "player_shoot", "direction" => %{"x" => x, "y" => y}}, ip, port, state) do
    client_key = {ip, port}
    
    case Map.get(state.clients, client_key) do
      nil ->
        Logger.warn("Unknown client #{inspect(ip)}:#{port} tried to shoot")
        {:noreply, state}
      
      client_info ->
        # 最後に見た時間を更新
        updated_client = %{client_info | last_seen: System.monotonic_time(:millisecond)}
        new_clients = Map.put(state.clients, client_key, updated_client)
        new_state = %{state | clients: new_clients}
        
        # ゲームサーバーに射撃を送信
        SimpleServer.GameServer.shoot(client_info.game_id, client_info.player_id, {x, y})
        
        {:noreply, new_state}
    end
  end

  defp handle_message(%{"type" => "test_message", "data" => data, "timestamp" => timestamp}, ip, port, state) do
    Logger.info("Test message from #{inspect(ip)}:#{port}: #{data} (timestamp: #{timestamp})")
    
    # テストメッセージへの応答を送信
    response = Jason.encode!(%{
      type: "test_response", 
      message: "Server received: #{data}",
      server_time: System.system_time(:second)
    })
    :gen_udp.send(state.socket, ip, port, response)
    
    {:noreply, state}
  end

  defp handle_message(%{"type" => "ping", "timestamp" => timestamp}, ip, port, state) do
    Logger.info("Ping from #{inspect(ip)}:#{port} (timestamp: #{timestamp})")
    
    # Pongメッセージを送信
    response = Jason.encode!(%{
      type: "pong", 
      client_timestamp: timestamp,
      server_timestamp: System.system_time(:second)
    })
    :gen_udp.send(state.socket, ip, port, response)
    
    {:noreply, state}
  end

  defp handle_message(%{"type" => "get_player_info", "player_id" => player_id}, ip, port, state) do
    Logger.info("Player info request for #{player_id} from #{inspect(ip)}:#{port}")
    
    client_key = {ip, port}
    client_info = Map.get(state.clients, client_key, %{})
    
    response = Jason.encode!(%{
      type: "player_info_response",
      player_id: player_id,
      client_info: client_info,
      connected_clients: map_size(state.clients)
    })
    :gen_udp.send(state.socket, ip, port, response)
    
    {:noreply, state}
  end

  defp handle_message(%{"type" => "get_game_state"}, ip, port, state) do
    Logger.info("Game state request from #{inspect(ip)}:#{port}")
    
    response = Jason.encode!(%{
      type: "game_state_response",
      total_clients: map_size(state.clients),
      clients: Enum.map(state.clients, fn {{client_ip, client_port}, client} ->
        %{
          ip: "#{:inet.ntoa(client_ip)}",
          port: client_port,
          player_id: client.player_id,
          game_id: client.game_id,
          team: client.team,
          last_seen: client.last_seen
        }
      end)
    })
    :gen_udp.send(state.socket, ip, port, response)
    
    {:noreply, state}
  end

  defp handle_message(message, ip, port, state) do
    Logger.warn("Unknown message type from #{inspect(ip)}:#{port}: #{inspect(message)}")
    
    # 不明なメッセージタイプへの応答
    response = Jason.encode!(%{
      type: "error",
      message: "Unknown message type",
      received: message
    })
    :gen_udp.send(state.socket, ip, port, response)
    
    {:noreply, state}
  end

  # パブリック関数：ゲームサーバーから呼び出される
  def broadcast_to_client(client_key, message) do
    GenServer.cast(__MODULE__, {:broadcast, client_key, message})
  end

  def broadcast_to_game_clients(game_id, message) do
    GenServer.cast(__MODULE__, {:broadcast_game, game_id, message})
  end

  def handle_cast({:broadcast, {ip, port}, message}, state) do
    json_message = Jason.encode!(message)
    :gen_udp.send(state.socket, ip, port, json_message)
    {:noreply, state}
  end

  def handle_cast({:broadcast_game, game_id, message}, state) do
    json_message = Jason.encode!(message)
    
    # 指定されたゲームのクライアントにブロードキャスト
    state.clients
    |> Enum.filter(fn {_key, client} -> client.game_id == game_id end)
    |> Enum.each(fn {{ip, port}, _client} ->
      :gen_udp.send(state.socket, ip, port, json_message)
    end)
    
    {:noreply, state}
  end

  # 定期的に非アクティブなクライアントをクリーンアップ
  def handle_info(:cleanup_clients, state) do
    current_time = System.monotonic_time(:millisecond)
    timeout = 30_000  # 30秒
    
    active_clients = 
      state.clients
      |> Enum.filter(fn {_key, client} -> 
        current_time - client.last_seen < timeout
      end)
      |> Enum.into(%{})
    
    removed_count = map_size(state.clients) - map_size(active_clients)
    if removed_count > 0 do
      Logger.info("Cleaned up #{removed_count} inactive clients")
    end
    
    # 次のクリーンアップをスケジュール
    Process.send_after(self(), :cleanup_clients, 30_000)
    
    {:noreply, %{state | clients: active_clients}}
  end

  def handle_info(msg, state) do
    Logger.warn("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info("UDP Server terminating: #{inspect(reason)}")
    :gen_udp.close(state.socket)
    :ok
  end
end