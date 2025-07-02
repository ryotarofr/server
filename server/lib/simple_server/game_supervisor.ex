defmodule SimpleServer.GameSupervisor do
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_game(game_id) do
    child_spec = {SimpleServer.GameServer, game_id}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def stop_game(game_id) do
    case Registry.lookup(SimpleServer.GameRegistry, game_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end