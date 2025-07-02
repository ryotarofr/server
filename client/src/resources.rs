use bevy::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::sync::mpsc::{Receiver, Sender};
use uuid::Uuid;

#[derive(Resource, Default)]
pub struct GameState {
    pub players: HashMap<Uuid, PlayerState>,
    pub painted_tiles: HashMap<(i32, i32), Color>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct PlayerState {
    pub id: Uuid,
    pub position: Vec2,
    pub health: i32,
    pub team: Team,
}

#[derive(Serialize, Deserialize, Clone, Copy, PartialEq)]
pub enum Team {
    Blue,
    Orange,
}

#[derive(Resource)]
pub struct NetworkClient {
    pub sender: Option<Sender<String>>,
    pub receiver: Option<Arc<Mutex<Receiver<String>>>>,
    pub player_id: Uuid,
    pub connected: bool,
}

impl Default for NetworkClient {
    fn default() -> Self {
        Self {
            sender: None,
            receiver: None,
            player_id: Uuid::new_v4(),
            connected: false,
        }
    }
}

#[derive(Serialize, Deserialize)]
pub enum GameMessage {
    PlayerJoin { player_id: Uuid, team: Team },
    PlayerMove { player_id: Uuid, position: Vec2 },
    PlayerShoot { player_id: Uuid, direction: Vec2 },
    TilePainted { position: (i32, i32), color: Color },
    GameState { players: Vec<PlayerState>, painted_tiles: HashMap<(i32, i32), Color> },
}