defmodule SplatoonServer.GameSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_game(game_id) do
    child_spec = {SplatoonServer.GameServer, game_id}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def stop_game(game_id) do
    case Registry.lookup(SplatoonServer.GameRegistry, game_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end

  @impl true
  def init(_init_arg) do
    # ゲームサーバー用のレジストリも開始
    Registry.start_link(keys: :unique, name: SplatoonServer.GameRegistry)
    
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end