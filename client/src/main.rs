use bevy::prelude::*;
use bevy::window::WindowPlugin;

mod components;
mod network;
mod resources;
mod systems;
mod udp_network;

use components::*;
use resources::*;
use systems::*;
use udp_network::*;

fn main() {
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "Splatoon Game".into(),
                resolution: (1280.0, 720.0).into(),
                ..default()
            }),
            ..default()
        }))
        .init_resource::<GameState>()
        .init_resource::<NetworkClient>()
        .add_systems(Startup, (setup, setup_udp_network))
        .add_systems(
            Update,
            (
                player_movement,
                send_player_position_udp,
                send_shoot_action_udp,
                local_shooting,
                paint_system,
                camera_follow,
                handle_udp_messages,
                monitor_connection,
                send_test_requests,
            ),
        )
        .run();
}

fn setup(mut commands: Commands) {
    // カメラ
    commands.spawn(Camera2dBundle::default());

    // テスト操作の説明をログに出力
    info!("🎮 Game Controls:");
    info!("  WASD/Arrow Keys - Move player");
    info!("  Mouse Click - Shoot");
    info!("🧪 Test Commands:");
    info!("  T - Send test message to server");
    info!("  P - Ping server");
    info!("  I - Request player info");
    info!("  G - Request game state");

    // プレイヤー
    commands.spawn((
        Player {
            id: uuid::Uuid::new_v4(),
        },
        SpriteBundle {
            sprite: Sprite {
                color: Color::BLUE,
                custom_size: Some(Vec2::new(30.0, 30.0)),
                ..default()
            },
            transform: Transform::from_xyz(0.0, 0.0, 1.0),
            ..default()
        },
        Velocity(Vec2::ZERO),
        Health(100),
    ));

    // 地面（ペイント可能エリア）
    for x in -20..20 {
        for y in -15..15 {
            commands.spawn((
                PaintableGround,
                SpriteBundle {
                    sprite: Sprite {
                        color: Color::WHITE,
                        custom_size: Some(Vec2::new(32.0, 32.0)),
                        ..default()
                    },
                    transform: Transform::from_xyz(x as f32 * 32.0, y as f32 * 32.0, 0.0),
                    ..default()
                },
                PaintColor(Color::WHITE),
            ));
        }
    }
}
