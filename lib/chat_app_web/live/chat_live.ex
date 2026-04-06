defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view

  alias Phoenix.PubSub
  alias ChatAppWeb.Presence

  @max_length 280      # max characters per message
  @max_members 3       # max members per room
  @typing_timeout 3000 # hide typing indicator after 3 seconds

  def mount(_params, session, socket) do
    # Read username and room from session (saved by SessionController)
    # If session is empty (first visit), use defaults
    username = session["username"] || "anon"
    room     = session["room"] || "lobby"

    # Build the PubSub topic from room name
    # Example: room "lobby" → topic "room:lobby"
    topic = "room:#{room}"

    is_audience =
      if connected?(socket) do
        # Subscribe to this room's topic — we will receive messages from here
        PubSub.subscribe(ChatApp.PubSub, topic)

        # Start the typing indicator cleanup timer
        # Every 3 seconds, :clear_typing message is sent to self
        Process.send_after(self(), :clear_typing, @typing_timeout)

        # Count how many members are currently in this room
        current_count = Presence.list(topic) |> map_size()

        if current_count < @max_members do
          # Room has space — track this user in Presence (they are a member)
          Presence.track(self(), topic, username, %{
            online_at: System.system_time(:second)
          })
          false  # is_audience = false (they can send messages)
        else
          # Room is full — do not track, they are audience (read only)
          true   # is_audience = true
        end
      else
        # WebSocket not connected yet — default to false, will re-check on connect
        false
      end

    {:ok,
     assign(socket,
       username:     username,
       room:         room,         # "lobby", "tamil", or "gaming"
       topic:        topic,        # "room:lobby" etc — used for PubSub
       message:      "",           # current text in input box
       messages:     [],           # list of all chat messages
       users:        [],           # list of online usernames
       remaining:    @max_length,  # characters left to type
       is_audience:  is_audience,  # true = read only, false = can send
       typing_users: %{}           # map of {username => last_typed_time}
     )}
  end

  # ========================
  # HANDLE EVENTS (from UI)
  # ========================

  # When user clicks Send button or presses Enter
  def handle_event("send", %{"message" => msg}, socket) do
    # Only send if: not audience, message not too long, message not empty
    if not socket.assigns.is_audience and
         String.length(msg) <= @max_length and
         msg != "" do

      message = %{
        user: socket.assigns.username,
        body: msg
      }

      # Broadcast this message to everyone in the same room topic
      PubSub.broadcast(ChatApp.PubSub, socket.assigns.topic, {:new_msg, message})

      # Clear the input box and reset character counter
      {:noreply, assign(socket, message: "", remaining: @max_length)}
    else
      # Do nothing if validation fails
      {:noreply, socket}
    end
  end

  # When user types in the message box (fires on every keystroke)
  def handle_event("update_message", %{"message" => msg}, socket) do
    # Tell everyone in the room that this user is typing
    # Only members can send typing indicator, not audience
    if not socket.assigns.is_audience do
      PubSub.broadcast(
        ChatApp.PubSub,
        socket.assigns.topic,
        {:typing, socket.assigns.username}
      )
    end

    # Update message text and recalculate remaining characters
    {:noreply,
     assign(socket,
       message:   msg,
       remaining: @max_length - String.length(msg)
     )}
  end

  # ===========================
  # HANDLE INFO (from PubSub)
  # ===========================

  # When a new message is broadcast to this room, add it to the list
  def handle_info({:new_msg, message}, socket) do
    # Append new message to end of messages list
    {:noreply, update(socket, :messages, fn msgs -> msgs ++ [message] end)}
  end

  # When someone in the room is typing, record them with current timestamp
  def handle_info({:typing, user}, socket) do
    # Ignore our own typing — we don't show "you are typing" to yourself
    if user != socket.assigns.username do
      typing_users =
        Map.put(
          socket.assigns.typing_users,
          user,
          System.system_time(:millisecond)  # record when they typed
        )
      {:noreply, assign(socket, typing_users: typing_users)}
    else
      {:noreply, socket}
    end
  end

  # This fires every 3 seconds — removes users who stopped typing
  def handle_info(:clear_typing, socket) do
    now = System.system_time(:millisecond)

    # Keep only users who typed within the last 3 seconds
    typing_users =
      socket.assigns.typing_users
      |> Enum.filter(fn {_user, time} -> now - time < @typing_timeout end)
      |> Enum.into(%{})

    # Schedule the next cleanup after 3 seconds
    Process.send_after(self(), :clear_typing, @typing_timeout)

    {:noreply, assign(socket, typing_users: typing_users)}
  end

  # When someone joins or leaves the room, update the users list
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff"},
        socket
      ) do
    # Get all current usernames in this room from Presence
    users = Presence.list(socket.assigns.topic) |> Map.keys()
    {:noreply, assign(socket, users: users)}
  end
end
