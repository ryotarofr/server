# Splatoon-like Game

RustのBevyエンジンを使ったクライアントとElixirを使ったサーバーで構成されるスプラトゥーン風ゲームです。

## プロジェクト構成

```
├── splatoon_client/    # Rust + Bevy クライアント
├── splatoon_server/    # Elixir + Phoenix サーバー（Phoenix依存の問題あり）
└── simple_server/      # シンプルなElixir + Cowboy サーバー（推奨）
```

## 機能

### クライアント (Rust + Bevy)
- プレイヤーの移動（WASD キー）
- マウスクリックでの射撃
- ペイント機能（弾丸が地面に当たるとペイント）
- カメラのプレイヤー追従
- リアルタイム通信（WebSocket）

### サーバー (Elixir)
- マルチプレイヤー対応
- ゲーム状態の管理（GenServer）
- プレイヤーの位置同期
- ペイント状態の管理
- リアルタイム通信（Phoenix Channels）

## セットアップ

### サーバー（Elixir）

1. Elixirをインストール
```bash
# Elixirのインストール（バージョン1.12以上）
# https://elixir-lang.org/install.html
```

2. サーバーの起動（推奨）
```bash
cd simple_server
mix deps.get
mix run --no-halt
```

サーバーは以下のポートで起動します：
- UDP通信: `localhost:8080`  
- HTTP情報: `http://localhost:8081`

**注意**: `splatoon_server`ディレクトリのPhoenixサーバーは現在の環境ではコンパイルエラーが発生するため、`simple_server`を使用してください。

### クライアント（Rust + Bevy）

1. Rustをインストール
```bash
# https://rustup.rs/
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

2. クライアントの実行
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
- **GameServer**: 各ゲームルームの状態を管理するGenServer
- **GameSupervisor**: ゲームサーバーの動的管理
- **WebSocketHandler**: WebSocket通信の処理
- **リアルタイム通信**: プレイヤー間の状態同期

### クライアント（Rust + Bevy）
- **Components**: エンティティの属性定義
- **Systems**: ゲームロジックの処理
- **Resources**: グローバル状態の管理
- **NetworkSystem**: サーバーとの通信処理

## 通信の仕組み

### UDP通信
クライアントとサーバー間はUDPで通信します。UDPはリアルタイムゲームに適した低遅延通信を提供します：

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

### UDP通信の特徴
- **低遅延**: TCP/WebSocketより高速な通信
- **軽量**: オーバーヘッドが少ない
- **リアルタイム**: ゲームに最適化された通信方式
- **パケット独立**: 各メッセージが独立して送信される

### 通信フロー
1. **クライアント起動** → UDP接続確立（localhost:8080）
2. **プレイヤー操作** → サーバーにUDPパケット送信
3. **サーバー処理** → ゲーム状態更新
4. **サーバー配信** → 全クライアントにUDPブロードキャスト
5. **クライアント受信** → 画面更新

### UDPパケット送信頻度
- **プレイヤー移動**: 位置変更時に送信
- **射撃**: マウスクリック時に送信
- **ゲーム状態**: サーバーから定期的に配信

## 今後の拡張予定

- [ ] チーム戦の実装
- [ ] スコアシステム
- [ ] より複雑なマップ
- [ ] パワーアップアイテム
- [ ] サウンド効果
- [ ] UI/UXの改善
- [ ] AI敵の追加

## トラブルシューティング

### よくある問題

1. **サーバーが起動しない**
   - Elixirとフェニックスが正しくインストールされているか確認
   - ポート4000が使用されていないか確認

2. **クライアントが重い**
   - Bevyの動的リンク機能を使用しているため、初回ビルドに時間がかかります
   - リリースビルドの場合は `cargo run --release` を使用

3. **接続できない**
   - サーバーが起動しているか確認
   - WebSocketの接続先URLが正しいか確認

## ライセンス

MIT License# server
