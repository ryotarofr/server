defmodule SplatoonServerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :splatoon_server

  @session_options [
    store: :cookie,
    key: "_splatoon_server_key",
    signing_salt: "splatoon_salt"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]
  socket "/socket", SplatoonServerWeb.UserSocket,
    websocket: true,
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: :splatoon_server,
    gzip: false

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug SplatoonServerWeb.Router
end