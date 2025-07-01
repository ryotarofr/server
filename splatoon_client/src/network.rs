use crate::resources::*;
use futures_util::{SinkExt, StreamExt};
use serde_json::json;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};

pub struct NetworkManager {
    server_url: String,
}

impl NetworkManager {
    pub fn new(server_url: String) -> Self {
        Self { server_url }
    }

    pub async fn connect(&self) -> Result<(), Box<dyn std::error::Error>> {
        let (ws_stream, _) = connect_async(&self.server_url).await?;
        let (mut write, mut read) = ws_stream.split();

        // ゲーム参加メッセージを送信
        let join_message = json!({
            "type": "join_game",
            "game_id": "default",
            "player_id": uuid::Uuid::new_v4().to_string(),
            "team": "blue"
        });
        
        let message_json = serde_json::to_string(&join_message)?;
        write.send(Message::Text(message_json)).await?;

        // メッセージ受信ループ
        while let Some(message) = read.next().await {
            match message? {
                Message::Text(text) => {
                    println!("Received: {}", text);
                }
                _ => {}
            }
        }

        Ok(())
    }

    pub async fn send_player_move(&mut self, position: (f32, f32)) -> Result<(), Box<dyn std::error::Error>> {
        let message = json!({
            "type": "player_move",
            "position": {
                "x": position.0,
                "y": position.1
            }
        });
        
        // WebSocketで送信する実装を追加
        Ok(())
    }

    pub async fn send_shoot(&mut self, direction: (f32, f32)) -> Result<(), Box<dyn std::error::Error>> {
        let message = json!({
            "type": "player_shoot",
            "direction": {
                "x": direction.0,
                "y": direction.1
            }
        });
        
        // WebSocketで送信する実装を追加
        Ok(())
    }
}