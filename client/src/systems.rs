use crate::components::*;
use crate::resources::*;
use bevy::prelude::*;

pub fn player_movement(
    keyboard_input: Res<Input<KeyCode>>,
    mut player_query: Query<(&mut Transform, &mut Velocity), With<Player>>,
    time: Res<Time>,
) {
    for (mut transform, mut velocity) in player_query.iter_mut() {
        let mut direction = Vec2::ZERO;

        if keyboard_input.pressed(KeyCode::W) || keyboard_input.pressed(KeyCode::Up) {
            direction.y += 1.0;
        }
        if keyboard_input.pressed(KeyCode::S) || keyboard_input.pressed(KeyCode::Down) {
            direction.y -= 1.0;
        }
        if keyboard_input.pressed(KeyCode::A) || keyboard_input.pressed(KeyCode::Left) {
            direction.x -= 1.0;
        }
        if keyboard_input.pressed(KeyCode::D) || keyboard_input.pressed(KeyCode::Right) {
            direction.x += 1.0;
        }

        if direction != Vec2::ZERO {
            direction = direction.normalize();
            velocity.0 = direction * 200.0;
        } else {
            velocity.0 = Vec2::ZERO;
        }

        transform.translation.x += velocity.0.x * time.delta_seconds();
        transform.translation.y += velocity.0.y * time.delta_seconds();
    }
}

pub fn local_shooting(
    mut commands: Commands,
    mouse_button_input: Res<Input<MouseButton>>,
    windows: Query<&Window>,
    camera_query: Query<(&Camera, &GlobalTransform)>,
    player_query: Query<(&Transform, &Player), With<Player>>,
) {
    if !mouse_button_input.just_pressed(MouseButton::Left) {
        return;
    }

    let window = windows.single();
    let (camera, camera_transform) = camera_query.single();

    if let Some(cursor_position) = window.cursor_position() {
        if let Some(world_position) = camera.viewport_to_world_2d(camera_transform, cursor_position)
        {
            for (player_transform, player) in player_query.iter() {
                let direction =
                    (world_position - player_transform.translation.truncate()).normalize();

                // ローカルエフェクト用の弾丸を生成
                commands.spawn((
                    Projectile {
                        owner: player.id,
                        color: Color::BLUE,
                        lifetime: 3.0,
                    },
                    SpriteBundle {
                        sprite: Sprite {
                            color: Color::BLUE,
                            custom_size: Some(Vec2::new(8.0, 8.0)),
                            ..default()
                        },
                        transform: Transform::from_translation(player_transform.translation),
                        ..default()
                    },
                    Velocity(direction * 400.0),
                ));
            }
        }
    }
}

pub fn paint_system(
    mut commands: Commands,
    mut projectile_query: Query<(Entity, &mut Transform, &Velocity, &mut Projectile)>,
    mut ground_query: Query<
        (&mut PaintColor, &mut Sprite, &Transform),
        (With<PaintableGround>, Without<Projectile>),
    >,
    time: Res<Time>,
) {
    for (entity, mut transform, velocity, mut projectile) in projectile_query.iter_mut() {
        transform.translation.x += velocity.0.x * time.delta_seconds();
        transform.translation.y += velocity.0.y * time.delta_seconds();

        projectile.lifetime -= time.delta_seconds();

        if projectile.lifetime <= 0.0 {
            commands.entity(entity).despawn();
            continue;
        }

        // 地面との衝突判定とペイント
        for (mut paint_color, mut sprite, ground_transform) in ground_query.iter_mut() {
            let distance = transform.translation.distance(ground_transform.translation);
            if distance < 16.0 {
                paint_color.0 = projectile.color;
                sprite.color = projectile.color;
                commands.entity(entity).despawn();
                break;
            }
        }
    }
}

pub fn camera_follow(
    player_query: Query<&Transform, (With<Player>, Without<Camera>)>,
    mut camera_query: Query<&mut Transform, (With<Camera>, Without<Player>)>,
) {
    if let Ok(player_transform) = player_query.get_single() {
        if let Ok(mut camera_transform) = camera_query.get_single_mut() {
            camera_transform.translation.x = player_transform.translation.x;
            camera_transform.translation.y = player_transform.translation.y;
        }
    }
}
