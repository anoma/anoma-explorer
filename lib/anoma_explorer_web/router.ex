defmodule AnomaExplorerWeb.Router do
  use AnomaExplorerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AnomaExplorerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AnomaExplorerWeb do
    pipe_through :browser

    get "/", PageController, :home

    # LiveView routes
    live "/activity", ActivityLive, :index
    live "/analytics", AnalyticsLive, :index

    # Settings routes
    live "/settings", SettingsLive, :index
    live "/settings/new", SettingsLive, :new
    live "/settings/:id/edit", SettingsLive, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", AnomaExplorerWeb do
  #   pipe_through :api
  # end
end
