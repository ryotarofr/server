use bevy::prelude::*;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Component, Serialize, Deserialize)]
pub struct Player {
    pub id: Uuid,
}

#[derive(Component)]
pub struct Velocity(pub Vec2);

#[derive(Component)]
pub struct Health(pub i32);

#[derive(Component)]
pub struct PaintableGround;

#[derive(Component)]
pub struct PaintColor(pub Color);

#[derive(Component)]
pub struct Projectile {
    pub owner: Uuid,
    pub color: Color,
    pub lifetime: f32,
}

#[derive(Component)]
pub struct PlayerCamera;