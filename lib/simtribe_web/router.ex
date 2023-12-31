defmodule SimTribeWeb.Router do
  use SimTribeWeb, :router

  import SimTribeWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SimTribeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :admin do
    plug :browser

  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SimTribeWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  scope "/api" do
    pipe_through :api

    forward "/graphql", Absinthe.Plug, schema: SimTribeWeb.Schema
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:simtribe, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SimTribeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: SimTribeWeb.Schema,
        interface: :playground,
        default_url: "/api/graphql"
    end
  end

  ## Authentication routes

  scope "/", SimTribeWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{SimTribeWeb.UserAuthLive, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", SimTribeWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SimTribeWeb.UserAuthLive, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", SimTribeWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{SimTribeWeb.UserAuthLive, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/admin", SimTribeWeb.Admin do
    pipe_through [:admin]

    live "/traits", TraitLive.Index, :index
    live "/traits/new", TraitLive.Index, :new
    live "/traits/:id/edit", TraitLive.Index, :edit

    live "/traits/:id", TraitLive.Show, :show
    live "/traits/:id/show/edit", TraitLive.Show, :edit
  end
end
