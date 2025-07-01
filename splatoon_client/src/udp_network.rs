use bevy::prelude::*;
use crate::resources::*;
use crate::components::*;
use serde_json::json;
use std::sync::{mpsc, Arc, Mutex};
use std::thread;
use tokio::net::UdpSocket;
use std::net::SocketAddr;
use std::sync::Arc as StdArc;

pub fn setup_udp_network(mut network_client: ResMut<NetworkClient>) {
    if network_client.connected {
        return;
    }

    let (to_server_tx, to_server_rx) = mpsc::channel::<String>();
    let (from_server_tx, from_server_rx) = mpsc::channel::<String>();

    let player_id = network_client.player_id;
    
    // UDP通信を別スレッドで処理
    thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            if let Err(e) = handle_udp_connection(player_id, to_server_rx, from_server_tx).await {
                eprintln!("UDP error: {}", e);
            }
        });
    });

    network_client.sender = Some(to_server_tx);
    network_client.receiver = Some(Arc::new(Mutex::new(from_server_rx)));
    network_client.connected = true;

    info!("UDP network connection established with player ID: {}", player_id);
}

async fn handle_udp_connection(
    player_id: uuid::Uuid,
    to_server_rx: mpsc::Receiver<String>,
    from_server_tx: mpsc::Sender<String>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    // UDPソケットをバインド（任意のポート）
    let socket = UdpSocket::bind("0.0.0.0:0").await?;
    let server_addr: SocketAddr = "127.0.0.1:8083".parse()?;
    
    println!("Connected to UDP server at {}", server_addr);

    // ゲーム参加メッセージを送信
    let join_message = json!({
        "type": "join_game",
        "game_id": "default",
        "player_id": player_id.to_string(),
        "team": "blue"
    });
    
    // 送信タスク用のソケットを作成
    let socket_arc = StdArc::new(socket);
    let socket_send = socket_arc.clone();
    let socket_recv = socket_arc.clone();
    
    socket_arc.send_to(join_message.to_string().as_bytes(), &server_addr).await?;
    
    let send_handle = tokio::spawn(async move {
        while let Ok(message) = to_server_rx.recv() {
            if let Err(e) = socket_send.send_to(message.as_bytes(), &server_addr).await {
                eprintln!("Failed to send UDP message: {}", e);
                break;
            }
        }
    });

    // 受信タスク
    let receive_handle = tokio::spawn(async move {
        let mut buffer = [0; 1024];
        
        loop {
            match socket_recv.recv_from(&mut buffer).await {
                Ok((len, _addr)) => {
                    if let Ok(message) = String::from_utf8(buffer[..len].to_vec()) {
                        if let Err(e) = from_server_tx.send(message) {
                            eprintln!("Failed to forward message to game: {}", e);
                            break;
                        }
                    }
                }
                Err(e) => {
                    eprintln!("UDP receive error: {}", e);
                    break;
                }
            }
        }
    });

    // どちらかのタスクが終了するまで待機
    tokio::select! {
        _ = send_handle => {}
        _ = receive_handle => {}
    }

    Ok(())
}

pub fn send_player_position_udp(
    player_query: Query<&Transform, (With<Player>, Changed<Transform>)>,
    network_client: Res<NetworkClient>,
) {
    if let Some(sender) = &network_client.sender {
        for transform in player_query.iter() {
            let message = json!({
                "type": "player_move",
                "position": {
                    "x": transform.translation.x,
                    "y": transform.translation.y
                }
            });
            
            if let Err(e) = sender.send(message.to_string()) {
                warn!("Failed to send position update: {}", e);
            }
        }
    }
}

pub fn send_shoot_action_udp(
    mouse_button_input: Res<Input<MouseButton>>,
    windows: Query<&Window>,
    camera_query: Query<(&Camera, &GlobalTransform)>,
    player_query: Query<&Transform, With<Player>>,
    network_client: Res<NetworkClient>,
) {
    if !mouse_button_input.just_pressed(MouseButton::Left) {
        return;
    }

    if let Some(sender) = &network_client.sender {
        let window = windows.single();
        let (camera, camera_transform) = camera_query.single();
        
        if let Some(cursor_position) = window.cursor_position() {
            if let Some(world_position) = camera.viewport_to_world_2d(camera_transform, cursor_position) {
                for player_transform in player_query.iter() {
                    let direction = (world_position - player_transform.translation.truncate()).normalize();
                    
                    let message = json!({
                        "type": "player_shoot",
                        "direction": {
                            "x": direction.x,
                            "y": direction.y
                        }
                    });
                    
                    if let Err(e) = sender.send(message.to_string()) {
                        warn!("Failed to send shoot action: {}", e);
                    }
                    break;
                }
            }
        }
    }
}

pub fn handle_udp_messages(
    network_client: Res<NetworkClient>,
    mut _game_state: ResMut<GameState>,
) {
    if let Some(receiver) = &network_client.receiver {
        if let Ok(receiver_guard) = receiver.try_lock() {
            while let Ok(message) = receiver_guard.try_recv() {
                if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&message) {
                    match parsed["type"].as_str() {
                        Some("connected") => {
                            info!("✅ Successfully connected to server");
                        }
                        Some("test_response") => {
                            if let Some(msg) = parsed["message"].as_str() {
                                info!("🧪 Test response: {}", msg);
                            }
                        }
                        Some("pong") => {
                            if let (Some(client_ts), Some(server_ts)) = (
                                parsed["client_timestamp"].as_i64(),
                                parsed["server_timestamp"].as_i64()
                            ) {
                                let rtt = server_ts - client_ts;
                                info!("🏓 Pong received - RTT: {}ms", rtt * 1000);
                            }
                        }
                        Some("player_info_response") => {
                            if let Some(player_id) = parsed["player_id"].as_str() {
                                let connected_clients = parsed["connected_clients"].as_i64().unwrap_or(0);
                                info!("👤 Player Info - ID: {}, Connected clients: {}", player_id, connected_clients);
                            }
                        }
                        Some("game_state_response") => {
                            let total_clients = parsed["total_clients"].as_i64().unwrap_or(0);
                            info!("🎮 Game State - Total clients: {}", total_clients);
                            if let Some(clients) = parsed["clients"].as_array() {
                                for client in clients {
                                    if let (Some(ip), Some(port), Some(team)) = (
                                        client["ip"].as_str(),
                                        client["port"].as_i64(),
                                        client["team"].as_str()
                                    ) {
                                        info!("  Client: {}:{} - Team: {}", ip, port, team);
                                    }
                                }
                            }
                        }
                        Some("error") => {
                            if let Some(error_msg) = parsed["message"].as_str() {
                                warn!("❌ Server error: {}", error_msg);
                            }
                        }
                        Some("game_state") => {
                            info!("📊 Received game state update");
                        }
                        Some("player_update") => {
                            if let Some(player_id) = parsed["player_id"].as_str() {
                                if let (Some(x), Some(y)) = (
                                    parsed["position"]["x"].as_f64(),
                                    parsed["position"]["y"].as_f64()
                                ) {
                                    info!("🏃 Player {} moved to ({}, {})", player_id, x, y);
                                }
                            }
                        }
                        Some("paint_update") => {
                            info!("🎨 Paint update received");
                        }
                        _ => {
                            info!("❓ Unknown message: {}", message);
                        }
                    }
                }
            }
        }
    }
}

// ネットワークの接続状態を監視
pub fn monitor_connection(
    _network_client: Res<NetworkClient>,
    _time: Res<Time>,
) {
    // 定期的にpingメッセージを送信したり、接続状態をチェック
    // 実装は簡略化
}

// テスト用のリクエスト送信
pub fn send_test_requests(
    keyboard_input: Res<Input<KeyCode>>,
    network_client: Res<NetworkClient>,
) {
    if let Some(sender) = &network_client.sender {
        // Tキーでテストメッセージを送信
        if keyboard_input.just_pressed(KeyCode::T) {
            let test_message = json!({
                "type": "test_message",
                "data": "Hello from client!",
                "timestamp": chrono::Utc::now().timestamp()
            });
            
            if let Err(e) = sender.send(test_message.to_string()) {
                warn!("Failed to send test message: {}", e);
            } else {
                info!("Sent test message to server");
            }
        }
        
        // Pキーでpingメッセージを送信
        if keyboard_input.just_pressed(KeyCode::P) {
            let ping_message = json!({
                "type": "ping",
                "timestamp": chrono::Utc::now().timestamp()
            });
            
            if let Err(e) = sender.send(ping_message.to_string()) {
                warn!("Failed to send ping: {}", e);
            } else {
                info!("Sent ping to server");
            }
        }
        
        // Iキーでプレイヤー情報リクエスト
        if keyboard_input.just_pressed(KeyCode::I) {
            let info_request = json!({
                "type": "get_player_info",
                "player_id": network_client.player_id.to_string()
            });
            
            if let Err(e) = sender.send(info_request.to_string()) {
                warn!("Failed to send info request: {}", e);
            } else {
                info!("Requested player info from server");
            }
        }
        
        // Gキーでゲーム状態リクエスト
        if keyboard_input.just_pressed(KeyCode::G) {
            let game_state_request = json!({
                "type": "get_game_state"
            });
            
            if let Err(e) = sender.send(game_state_request.to_string()) {
                warn!("Failed to send game state request: {}", e);
            } else {
                info!("Requested game state from server");
            }
        }
    }
}