defmodule ChatAppWeb.SessionController do
  use ChatAppWeb, :controller

  # This is called when user submits the join form
  # It saves username and room into browser session
  # Then redirects to the chat page
  def save(conn, %{"username" => username, "room" => room}) do
    conn
    |> put_session(:username, username)  # save username in session cookie
    |> put_session(:room, room)          # save room in session cookie
    |> redirect(to: "/chat")             # go to chat page
  end
end
