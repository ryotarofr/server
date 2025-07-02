use bevy::prelude::*;
use crate::resources::*;
use crate::components::*;
use serde_json::json;
use std::sync::mpsc;
use std::thread;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
use futures_util::{SinkExt, StreamExt};

pub fn setup_network(mut network_client: ResMut<NetworkClient>) {
    if network_client.connected {
        return;
    }

    let (to_server_tx, to_server_rx) = mpsc::channel::<String>();
    let (from_server_tx, from_server_rx) = mpsc::channel::<String>();

    // WebSocket接続を別スレッドで処理
    let player_id = network_client.player_id;
    thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            if let Err(e) = handle_websocket_connection(player_id, to_server_rx, from_server_tx).await {
                eprintln!("WebSocket error: {}", e);
            }
        });
    });

    network_client.sender = Some(to_server_tx);
    network_client.receiver = Some(from_server_rx);
    network_client.connected = true;

    info!("Network connection established with player ID: {}", player_id);
}

async fn handle_websocket_connection(
    player_id: uuid::Uuid,
    to_server_rx: mpsc::Receiver<String>,
    from_server_tx: mpsc::Sender<String>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let url = "ws://localhost:8080/ws";
    let (ws_stream, _) = connect_async(url).await?;
    let (mut write, mut read) = ws_stream.split();

    // ゲーム参加メッセージを送信
    let join_message = json!({
        "type": "join_game",
        "game_id": "default",
        "player_id": player_id.to_string(),
        "team": "blue"
    });
    
    write.send(Message::Text(join_message.to_string())).await?;

    // 送信ループ
    let write_handle = {
        let mut write = write;
        tokio::spawn(async move {
            while let Ok(message) = to_server_rx.recv() {
                if let Err(e) = write.send(Message::Text(message)).await {
                    eprintln!("Failed to send message: {}", e);
                    break;
                }
            }
        })
    };

    // 受信ループ
    let read_handle = tokio::spawn(async move {
        while let Some(message) = read.next().await {
            match message {
                Ok(Message::Text(text)) => {
                    if let Err(e) = from_server_tx.send(text) {
                        eprintln!("Failed to send message to game: {}", e);
                        break;
                    }
                }
                Ok(_) => {}
                Err(e) => {
                    eprintln!("WebSocket error: {}", e);
                    break;
                }
            }
        }
    });

    // 両方のタスクが完了するまで待機
    tokio::try_join!(write_handle, read_handle)?;
    Ok(())
}

pub fn send_player_position(
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

pub fn handle_server_messages(
    mut network_client: ResMut<NetworkClient>,
    mut game_state: ResMut<GameState>,
) {
    if let Some(receiver) = &network_client.receiver {
        while let Ok(message) = receiver.try_recv() {
            if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&message) {
                match parsed["type"].as_str() {
                    Some("game_state") => {
                        info!("Received game state: {}", message);
                        // ゲーム状態を更新
                    }
                    Some("player_update") => {
                        info!("Player update: {}", message);
                        // プレイヤー位置を更新
                    }
                    Some("paint_update") => {
                        info!("Paint update: {}", message);
                        // ペイント状態を更新
                    }
                    _ => {
                        info!("Unknown message type: {}", message);
                    }
                }
            }
        }
    }
}

pub fn send_shoot_action(
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