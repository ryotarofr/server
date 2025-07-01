import Config

config :splatoon_server, SplatoonServerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: SplatoonServerWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: SplatoonServer.PubSub,
  live_view: [signing_salt: "splatoon_live_view"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"