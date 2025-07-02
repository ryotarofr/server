# ほげ

```bash
cd server
mix deps.get
mix run --no-halt
```

- UDP 通信: `localhost:8080`
- HTTP 情報: `http://localhost:8081`

```bash
cd client
cargo run
```

```rust
// クライアント側で自動的に実行
setup_udp_network() // ゲーム開始時にUDP接続を確立
```

#### 2. メッセージ形式

```json
// ゲーム参加
{
  "type": "join_game",
  "game_id": "default",
  "player_id": "uuid",
  "team": "blue"
}

// プレイヤー移動
{
  "type": "player_move",
  "position": {"x": 100.0, "y": 200.0}
}

// 射撃
{
  "type": "player_shoot",
  "direction": {"x": 1.0, "y": 0.0}
}
```

#### 3. サーバーからの応答

```json
// ゲーム状態更新
{
  "type": "game_state",
  "players": [...],
  "painted_tiles": [...]
}

// プレイヤー位置更新
{
  "type": "player_update",
  "player_id": "uuid",
  "position": {"x": 100.0, "y": 200.0}
}

// ペイント更新
{
  "type": "paint_update",
  "painted_areas": [...]
}
```
