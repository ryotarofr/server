defmodule SplatoonServerWeb.ErrorView do
  use SplatoonServerWeb, :view

  def render("404.html", _assigns) do
    "Not Found"
  end

  def render("500.html", _assigns) do
    "Internal Server Error"
  end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end