defmodule SplatoonServerWeb do
  def controller do
    quote do
      use Phoenix.Controller, namespace: SplatoonServerWeb

      import Plug.Conn
      import SplatoonServerWeb.Gettext
      alias SplatoonServerWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/splatoon_server_web/templates",
        namespace: SplatoonServerWeb

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      use Phoenix.HTML

      import SplatoonServerWeb.ErrorHelpers
      import SplatoonServerWeb.Gettext
      alias SplatoonServerWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import SplatoonServerWeb.Gettext
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end