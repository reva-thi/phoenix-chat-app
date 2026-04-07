# defmodule ChatAppWeb.ChatLive do
#   use ChatAppWeb, :live_view

#   alias Phoenix.PubSub
#   alias ChatAppWeb.Presence

#   @max_length 280      # max characters per message
#   @max_members 3       # max members per room
#   @typing_timeout 3000 # hide typing indicator after 3 seconds

#   def mount(_params, session, socket) do
#     # Read username and room from session (saved by SessionController)
#     # If session is empty (first visit), use defaults
#     username = session["username"] || "anon"
#     room     = session["room"] || "lobby"

#     # Build the PubSub topic from room name
#     # Example: room "lobby" → topic "room:lobby"
#     topic = "room:#{room}"
#     # Each user gets their own private channel
#     # Only they subscribe to this — so @tagged msgs come only to them
#     private_topic = "private:#{username}"

#     is_audience =
#       if connected?(socket) do
#         # Subscribe to this room's topic — we will receive messages from here
#         PubSub.subscribe(ChatApp.PubSub, topic)
#         # Subscribe to private topic too — so we receive @tagged messages
#         PubSub.subscribe(ChatApp.PubSub, private_topic)

#         # Start the typing indicator cleanup timer
#         # Every 3 seconds, :clear_typing message is sent to self
#         Process.send_after(self(), :clear_typing, @typing_timeout)

#         # Count how many members are currently in this room
#         current_count = Presence.list(topic) |> map_size()

#         if current_count < @max_members do
#           # Room has space — track this user in Presence (they are a member)
#           Presence.track(self(), topic, username, %{
#             online_at: System.system_time(:second)
#           })
#           false  # is_audience = false (they can send messages)
#         else
#           # Room is full — do not track, they are audience (read only)
#           true   # is_audience = true
#         end
#       else
#         # WebSocket not connected yet — default to false, will re-check on connect
#         false
#       end
#       initial_users = Presence.list(topic) |> Map.keys()

#     {:ok,
#      assign(socket,
#        username:     username,
#        room:         room,         # "lobby", "tamil", or "gaming"
#        topic:        topic,       # "room:lobby" etc — used for PubSub
#        private_topic: private_topic,        # ADD this line

#        message:      "",           # current text in input box
#        messages:
#           :ets.tab2list(:chat_messages)
#           |> Enum.filter(fn {_id, msg_room, _msg} ->
#             msg_room == room
#           end)
#           |> Enum.sort()
#           |> Enum.map(fn {_id, _room, msg} -> msg end),
#        users:        [],           # list of online usernames
#        messages:     [],           # list of all chat messages
#        users:        initial_users,           # list of online usernames
#        remaining:    @max_length,  # characters left to type
#        is_audience:  is_audience,  # true = read only, false = can send
#        typing_users: %{},
#        mention_query:       nil,  # tracks what user typed after @
#        mention_suggestions: []    # list of users shown in popup           # map of {username => last_typed_time}
#      )}
#   end

#   # ========================
#   # HANDLE EVENTS (from UI)
#   # ========================

#   # When user clicks Send button or presses Enter
#   def handle_event("send", %{"message" => msg}, socket) do
#     # Only send if: not audience, message not too long, message not empty
#     if not socket.assigns.is_audience and
#          String.length(msg) <= @max_length and
#          msg != "" do

#       message = %{
#         user: socket.assigns.username,
#         body: msg
#       }

#       # STORE IN ETS
#       :ets.insert(:chat_messages, {
#         System.unique_integer([:positive]),
#         socket.assigns.room,
#         message
#         })

#       # Broadcast this message to everyone in the same room topic
#       PubSub.broadcast(ChatApp.PubSub, socket.assigns.topic, {:new_msg, message})
#   user:   socket.assigns.username,
#   body:   msg,
#   tagged: nil   # nil means normal message, not private
#       }

# # Check if message has @username in it
# case extract_tagged_user(msg, socket.assigns.users) do
#   nil ->
#     # No @tag — send to whole room as usual
#     PubSub.broadcast(ChatApp.PubSub, socket.assigns.topic, {:new_msg, message})

#   tagged_username ->
#   private_msg = %{message | tagged: tagged_username}

#   # Send to receiver's private topic — only they get it
#   PubSub.broadcast(
#     ChatApp.PubSub,
#     "private:#{tagged_username}",
#     {:new_msg, private_msg}
#   )

#   # Send to sender's own private topic too
#   # So sender can see what they sent on their screen
#   # Without this, sender screen shows nothing after sending
#   if tagged_username != socket.assigns.username do
#     PubSub.broadcast(
#       ChatApp.PubSub,
#       socket.assigns.private_topic,
#       {:new_msg, private_msg}
#     )
#   end
# end

#       # Clear the input box and reset character counter
#       {:noreply, assign(socket, message: "", remaining: @max_length)}
#     else
#       # Do nothing if validation fails
#       {:noreply, socket}
#     end
#   end

#   # When user types in the message box (fires on every keystroke)
#   def handle_event("update_message", %{"message" => msg}, socket) do
#   if not socket.assigns.is_audience do
#     PubSub.broadcast(
#       ChatApp.PubSub,
#       socket.assigns.topic,
#       {:typing, socket.assigns.username}
#     )
#   end

#   # Check if user is currently typing @something
#   # Regex looks for @ followed by letters at the END of message
#   # Example: "hello @ra" → mention_query = "ra"
#   # Example: "hello world" → mention_query = nil
#   mention_query =
#     case Regex.run(~r/@(\S*)$/, msg) do
#       [_full, query] -> query   # found @ — return what they typed after @
#       nil            -> nil     # no @ at end — no popup needed
#     end

#   # Filter online users whose name starts with what user typed
#   # Example: query="ra", users=["ravi-1","karthiga-2"] → ["ravi-1"]
#   mention_suggestions =
#     if mention_query != nil do
#       socket.assigns.users
#       |> Enum.filter(fn user ->
#         user != socket.assigns.username and
#         String.starts_with?(String.downcase(user), String.downcase(mention_query))
#       end)
#     else
#       []  # empty list — no popup
#     end

#   {:noreply,
#    assign(socket,
#      message:             msg,
#      remaining:           @max_length - String.length(msg),
#      mention_query:       mention_query,       # what user typed after @
#      mention_suggestions: mention_suggestions  # filtered user list for popup
#    )}
# end

#   # ===========================
#   # HANDLE INFO (from PubSub)
#   # ===========================

#   # When a new message is broadcast to this room, add it to the list
#   def handle_info({:new_msg, message}, socket) do
#     # Append new message to end of messages list
#     {:noreply, update(socket, :messages, fn msgs -> msgs ++ [message] end)}
#   end

#   # When someone in the room is typing, record them with current timestamp
#   def handle_info({:typing, user}, socket) do
#     # Ignore our own typing — we don't show "you are typing" to yourself
#     if user != socket.assigns.username do
#       typing_users =
#         Map.put(
#           socket.assigns.typing_users,
#           user,
#           System.system_time(:millisecond)  # record when they typed
#         )
#       {:noreply, assign(socket, typing_users: typing_users)}
#     else
#       {:noreply, socket}
#     end
#   end

#   # This fires every 3 seconds — removes users who stopped typing
#   def handle_info(:clear_typing, socket) do
#     now = System.system_time(:millisecond)

#     # Keep only users who typed within the last 3 seconds
#     typing_users =
#       socket.assigns.typing_users
#       |> Enum.filter(fn {_user, time} -> now - time < @typing_timeout end)
#       |> Enum.into(%{})

#     # Schedule the next cleanup after 3 seconds
#     Process.send_after(self(), :clear_typing, @typing_timeout)

#     {:noreply, assign(socket, typing_users: typing_users)}
#   end

#   # When someone joins or leaves the room, update the users list
#   def handle_info(
#         %Phoenix.Socket.Broadcast{event: "presence_diff"},
#         socket
#       ) do
#     # Get all current usernames in this room from Presence
#     users = Presence.list(socket.assigns.topic) |> Map.keys()
#     {:noreply, assign(socket, users: users)}
#   end
#   # When user clicks a name from the @ suggestion popup
# # Replace the @partial text with the full username
# # Example: message="hello @ra", clicked "ravi-1234"
# # Result:  message="hello @ravi-1234 "
# def handle_event("select_mention", %{"username" => selected}, socket) do
#   current_msg = socket.assigns.message

#   # Remove the partial @query from end of message
#   # Replace with full @username + space
#   new_msg =
#     Regex.replace(~r/@(\S*)$/, current_msg, "@#{selected} ")

#   {:noreply,
#    assign(socket,
#      message:             new_msg,
#      remaining:           @max_length - String.length(new_msg),
#      mention_suggestions: [],    # close the popup
#      mention_query:       nil
#    )}
# end
#   # Scan message for @username patterns
# # Check if that username is actually online in the room
# # Returns username string if found, nil if not
# defp extract_tagged_user(msg, users) do
#   Regex.scan(~r/@(\S+)/, msg)
#   |> Enum.map(fn [_full, name] -> name end)
#   |> Enum.find(fn name -> Enum.member?(users, name) end)
# end

# # Replace @username in text with blue highlighted HTML span
# # Example: "@ravi hello" → "<span class='...'>@ravi</span> hello"
# defp highlight_mentions(text) do
#   Regex.replace(~r/@(\S+)/, text, fn match, _name ->
#     "<span class='font-bold text-blue-600'>#{match}</span>"
#   end)
# end
# end
defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view

  alias Phoenix.PubSub
  alias ChatAppWeb.Presence

  @max_length 280      # max characters per message
  @max_members 3       # max members per room
  @typing_timeout 3000 # hide typing indicator after 3 seconds

  def mount(_params, session, socket) do
    # Read username and room from session (saved by SessionController)
    username = session["username"] || "anon"
    room     = session["room"] || "lobby"

    topic = "room:#{room}"
    private_topic = "private:#{username}"

    is_audience =
      if connected?(socket) do
        PubSub.subscribe(ChatApp.PubSub, topic)
        PubSub.subscribe(ChatApp.PubSub, private_topic)

        Process.send_after(self(), :clear_typing, @typing_timeout)

        current_count = Presence.list(topic) |> map_size()

        if current_count < @max_members do
          Presence.track(self(), topic, username, %{
            online_at: System.system_time(:second)
          })
          false
        else
          true
        end
      else
        false
      end

    initial_users = Presence.list(topic) |> Map.keys()

    {:ok,
     assign(socket,
       username: username,
       room: room,
       topic: topic,
       private_topic: private_topic,
       message: "",
       messages:
         :ets.tab2list(:chat_messages)
         |> Enum.filter(fn {_id, msg_room, _msg} -> msg_room == room end)
         |> Enum.sort()
         |> Enum.map(fn {_id, _room, msg} -> msg end),
       users: initial_users,
       remaining: @max_length,
       is_audience: is_audience,
       typing_users: %{},
       mention_query: nil,
       mention_suggestions: []
     )}
  end

  # ========================
  # HANDLE EVENTS (from UI)
  # ========================

  def handle_event("send", %{"message" => msg}, socket) do
    if not socket.assigns.is_audience and
         String.length(msg) <= @max_length and
         msg != "" do

      # ---------------------------------------------------------
      # | FIXED SECTION START                                   |
      # ---------------------------------------------------------
      message = %{
        user: socket.assigns.username,
        body: msg,
        tagged: nil
      }

      # STORE IN ETS
      :ets.insert(:chat_messages, {
        System.unique_integer([:positive]),
        socket.assigns.room,
        message
      })

      # Check if message has @username in it
      case extract_tagged_user(msg, socket.assigns.users) do
        nil ->
          # No @tag — send to whole room as usual
          PubSub.broadcast(ChatApp.PubSub, socket.assigns.topic, {:new_msg, message})

        tagged_username ->
          private_msg = %{message | tagged: tagged_username}

          # Send to receiver's private topic
          PubSub.broadcast(ChatApp.PubSub, "private:#{tagged_username}", {:new_msg, private_msg})

          # Send to sender's own private topic (to see it on their screen)
          if tagged_username != socket.assigns.username do
            PubSub.broadcast(ChatApp.PubSub, socket.assigns.private_topic, {:new_msg, private_msg})
          end
      end
      # | FIXED SECTION END                                     |
      # ---------------------------------------------------------

      {:noreply, assign(socket, message: "", remaining: @max_length)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_message", %{"message" => msg}, socket) do
    if not socket.assigns.is_audience do
      PubSub.broadcast(ChatApp.PubSub, socket.assigns.topic, {:typing, socket.assigns.username})
    end

    mention_query =
      case Regex.run(~r/@(\S*)$/, msg) do
        [_full, query] -> query
        nil -> nil
      end

    mention_suggestions =
      if mention_query != nil do
        socket.assigns.users
        |> Enum.filter(fn user ->
          user != socket.assigns.username and
            String.starts_with?(String.downcase(user), String.downcase(mention_query))
        end)
      else
        []
      end

    {:noreply,
     assign(socket,
       message: msg,
       remaining: @max_length - String.length(msg),
       mention_query: mention_query,
       mention_suggestions: mention_suggestions
     )}
  end

  def handle_event("select_mention", %{"username" => selected}, socket) do
    current_msg = socket.assigns.message
    new_msg = Regex.replace(~r/@(\S*)$/, current_msg, "@#{selected} ")

    {:noreply,
     assign(socket,
       message: new_msg,
       remaining: @max_length - String.length(new_msg),
       mention_suggestions: [],
       mention_query: nil
     )}
  end

  # ===========================
  # HANDLE INFO (from PubSub)
  # ===========================

  def handle_info({:new_msg, message}, socket) do
    {:noreply, update(socket, :messages, fn msgs -> msgs ++ [message] end)}
  end

  def handle_info({:typing, user}, socket) do
    if user != socket.assigns.username do
      typing_users = Map.put(socket.assigns.typing_users, user, System.system_time(:millisecond))
      {:noreply, assign(socket, typing_users: typing_users)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:clear_typing, socket) do
    now = System.system_time(:millisecond)

    typing_users =
      socket.assigns.typing_users
      |> Enum.filter(fn {_user, time} -> now - time < @typing_timeout end)
      |> Enum.into(%{})

    Process.send_after(self(), :clear_typing, @typing_timeout)
    {:noreply, assign(socket, typing_users: typing_users)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    users = Presence.list(socket.assigns.topic) |> Map.keys()
    {:noreply, assign(socket, users: users)}
  end

  # ===========================
  # PRIVATE HELPERS
  # ===========================

  defp extract_tagged_user(msg, users) do
    Regex.scan(~r/@(\S+)/, msg)
    |> Enum.map(fn [_full, name] -> name end)
    |> Enum.find(fn name -> Enum.member?(users, name) end)
  end

  defp highlight_mentions(text) do
    Regex.replace(~r/@(\S+)/, text, fn match, _name ->
      "<span class='font-bold text-blue-600'>#{match}</span>"
    end)
  end
end
