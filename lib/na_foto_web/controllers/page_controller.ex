defmodule NaFotoWeb.PageController do
  use NaFotoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
