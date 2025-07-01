# ほげ

Rust の Bevy エンジンを使ったクライアントと Elixir を使ったサーバーで構成

```bash
cd simple_server
mix deps.get
mix run --no-halt
```

サーバーは以下のポートで起動します：

- UDP 通信: `localhost:8080`
- HTTP 情報: `http://localhost:8081`

```bash
cd splatoon_client
cargo run
```

## 操作方法

- **移動**: W/A/S/D キーまたは矢印キー
- **射撃**: マウス左クリック（クリックした方向に弾丸が飛びます）
- **カメラ**: プレイヤーを自動追従

## アーキテクチャ

### サーバー（Elixir）

- **GameServer**: 各ゲームルームの状態を管理する GenServer
- **GameSupervisor**: ゲームサーバーの動的管理
- **WebSocketHandler**: WebSocket 通信の処理
- **リアルタイム通信**: プレイヤー間の状態同期

### クライアント（Rust + Bevy）

- **Components**: エンティティの属性定義
- **Systems**: ゲームロジックの処理
- **Resources**: グローバル状態の管理
- **NetworkSystem**: サーバーとの通信処理

## 通信の仕組み

### UDP 通信

クライアントとサーバー間は UDP で通信します。UDP はリアルタイムゲームに適した低遅延通信を提供します：

#### 1. 接続確立

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

### UDP 通信の特徴

- **低遅延**: TCP/WebSocket より高速な通信
- **軽量**: オーバーヘッドが少ない
- **リアルタイム**: ゲームに最適化された通信方式
- **パケット独立**: 各メッセージが独立して送信される

### 通信フロー

1. **クライアント起動** → UDP 接続確立（localhost:8080）
2. **プレイヤー操作** → サーバーに UDP パケット送信
3. **サーバー処理** → ゲーム状態更新
4. **サーバー配信** → 全クライアントに UDP ブロードキャスト
5. **クライアント受信** → 画面更新

### UDP パケット送信頻度

- **プレイヤー移動**: 位置変更時に送信
- **射撃**: マウスクリック時に送信
- **ゲーム状態**: サーバーから定期的に配信

## 今後の拡張予定

- [ ] チーム戦の実装
- [ ] スコアシステム
- [ ] より複雑なマップ
- [ ] パワーアップアイテム
- [ ] サウンド効果
- [ ] UI/UX の改善
- [ ] AI 敵の追加

## トラブルシューティング

### よくある問題

1. **サーバーが起動しない**

   - Elixir とフェニックスが正しくインストールされているか確認
   - ポート 4000 が使用されていないか確認

2. **クライアントが重い**

   - Bevy の動的リンク機能を使用しているため、初回ビルドに時間がかかります
   - リリースビルドの場合は `cargo run --release` を使用

3. **接続できない**
   - サーバーが起動しているか確認
   - WebSocket の接続先 URL が正しいか確認

## ライセンス

MIT License# server
