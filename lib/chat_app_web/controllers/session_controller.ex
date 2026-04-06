defmodule ChatAppWeb.SessionController do
  use ChatAppWeb, :controller

  def save(conn, %{"username" => username, "room" => room}) do
    conn
    |> put_session(:username, username)
    |> put_session(:room, room)
    |> redirect(to: "/chat")
  end
end