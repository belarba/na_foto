defmodule NaFotoWeb.Router do
  use NaFotoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NaFotoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NaFotoWeb do
    pipe_through :browser

    live "/", UploadLive, :index
    live "/history", HistoryLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", NaFotoWeb do
  #   pipe_through :api
  # end
end
