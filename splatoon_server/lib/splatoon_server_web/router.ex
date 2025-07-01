defmodule SplatoonServerWeb.Router do
  use SplatoonServerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", SplatoonServerWeb do
    pipe_through :api
    
    get "/games/:game_id/state", GameController, :show
    post "/games", GameController, :create
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: SplatoonServerWeb.Telemetry
    end
  end
end