defmodule SimpleServer.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: SimpleServer.GameRegistry},
      SimpleServer.GameSupervisor,
      SimpleServer.UdpServer
    ]

    # HTTPサーバーも起動（情報表示用）
    dispatch_config = build_dispatch_config()
    {:ok, _} = :cowboy.start_clear(
      :http_listener,
      [{:port, 8081}],
      %{env: %{dispatch: dispatch_config}}
    )

    opts = [strategy: :one_for_one, name: SimpleServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp build_dispatch_config do
    :cowboy_router.compile([
      {:_, [
        {"/", :cowboy_static, {:priv_file, :simple_server, "index.html"}},
        {"/[...]", :cowboy_static, {:priv_dir, :simple_server, "static"}}
      ]}
    ])
  end
end