defmodule ChatAppWeb.JoinLive do
  use ChatAppWeb, :live_view
  alias ChatAppWeb.Presence

  @max_members 3

  @rooms [
    %{id: "lobby",  name: "Lobby",  emoji: "🏠"},
    %{id: "tamil",  name: "Tamil",  emoji: "🗣️"},
    %{id: "gaming", name: "Gaming", emoji: "🎮"}
  ]

  def mount(_params, _session, socket) do
    default_room = "lobby"

    if connected?(socket) do
      Enum.each(@rooms, fn room ->
        Phoenix.PubSub.subscribe(ChatApp.PubSub, "room:#{room.id}")
      end)
    end

    room_counts = get_room_counts()

    {:ok,
     assign(socket,
       rooms: @rooms,
       selected_room: default_room,
       room_counts: room_counts,
       max_members: @max_members,
       username: ""              # NEW — username track பண்றோம்
     )}
  end

  # Room button click — just update selected room, username stays safe
  def handle_event("select_room", %{"room" => room_id}, socket) do
    {:noreply, assign(socket, selected_room: room_id)}
  end

  # NEW — username type பண்ணும்போது save பண்றோம்
  def handle_event("update_username", %{"username" => name}, socket) do
    {:noreply, assign(socket, username: name)}
  end

  # Form submit
  def handle_event("join", %{"username" => name}, socket) do
    if String.trim(name) == "" do
      {:noreply, socket}
    else
      unique_id   = :rand.uniform(9999)
      unique_name = "#{String.trim(name)}-#{unique_id}"
      room        = socket.assigns.selected_room

      {:noreply,
       push_navigate(socket,
         to: "/save_session?username=#{unique_name}&room=#{room}"
       )}
    end
  end

  # Presence diff — update room counts
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff", topic: topic},
        socket
      ) do
    room_id    = String.replace_prefix(topic, "room:", "")
    new_count  = Presence.list(topic) |> map_size()
    updated    = Map.put(socket.assigns.room_counts, room_id, new_count)
    {:noreply, assign(socket, room_counts: updated)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-100 to-indigo-200">
      <div class="bg-white shadow-2xl rounded-2xl p-8 w-full max-w-md">

        <h1 class="text-2xl font-bold text-center text-gray-800 mb-1">
          💬 Welcome to Chat
        </h1>
        <p class="text-center text-gray-400 text-sm mb-6">
          Enter your name and pick a room
        </p>

        <form phx-submit="join" class="flex flex-col gap-5">

          <!-- Name input — phx-change saves username as you type -->
          <input
            type="text"
            name="username"
            value={@username}
            phx-change="update_username"
            placeholder="Enter your name..."
            required
            class="border border-gray-300 rounded-lg p-3 focus:outline-none focus:ring-2 focus:ring-blue-400"
          />

          <!-- Show username preview if typed -->
          <%= if String.trim(@username) != "" do %>
            <p class="text-sm text-blue-600 -mt-3">
              Hello, <strong><%= @username %></strong>! 👋 Now pick a room below.
            </p>
          <% end %>

          <!-- Room selection -->
          <div>
            <p class="text-sm font-semibold text-gray-600 mb-2">
              Select a Room:
            </p>

            <div class="flex flex-col gap-2">
              <%= for room <- @rooms do %>
                <%
                  count       = Map.get(@room_counts, room.id, 0)
                  is_full     = count >= @max_members
                  is_selected = @selected_room == room.id
                  percent     = trunc(min(count * 100 / @max_members, 100))

                  border_class = cond do
                    is_selected and is_full -> "border-orange-400 bg-orange-50"
                    is_selected             -> "border-blue-500 bg-blue-50"
                    true                    -> "border-gray-200 bg-white hover:border-gray-300"
                  end
                %>

                <!-- type="button" VERY IMPORTANT — prevents form submit on room click -->
                <button
                  type="button"
                  phx-click="select_room"
                  phx-value-room={room.id}
                  class={"w-full flex items-center justify-between px-4 py-3 rounded-xl border-2 transition " <> border_class}
                >
                  <div class="flex items-center gap-3">
                    <span class="text-2xl"><%= room.emoji %></span>
                    <span class={"font-semibold " <> if(is_selected, do: "text-blue-700", else: "text-gray-700")}>
                      <%= room.name %>
                    </span>
                    <%= if is_selected do %>
                      <span class="text-xs bg-blue-500 text-white px-2 py-0.5 rounded-full">
                        selected
                      </span>
                    <% end %>
                  </div>

                  <div class="flex items-center gap-2">
                    <div class="w-16 h-1.5 bg-gray-200 rounded-full">
                      <div
                        class={"h-1.5 rounded-full " <> if(is_full, do: "bg-red-400", else: "bg-green-400")}
                        style={"width: #{percent}%"}
                      >
                      </div>
                    </div>
                    <span class={"text-xs font-medium " <> if(is_full, do: "text-red-500", else: "text-green-600")}>
                      <%= count %>/<%= @max_members %>
                    </span>
                  </div>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Selected room status -->
          <%
            sel_count = Map.get(@room_counts, @selected_room, 0)
            sel_full  = sel_count >= @max_members
          %>
          <div class="flex justify-center">
            <%= if sel_full do %>
              <span class="bg-orange-100 text-orange-700 text-sm px-4 py-1 rounded-full">
                🔴 Room full — you will join as audience
              </span>
            <% else %>
              <span class="bg-green-100 text-green-700 text-sm px-4 py-1 rounded-full">
                🟢 <%= sel_count %>/<%= @max_members %> — room available
              </span>
            <% end %>
          </div>

          <!-- Submit button -->
          <button
            type="submit"
            class="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-3 rounded-lg transition"
          >
            <%= if sel_full, do: "Join as Audience 👀", else: "Join Chat 🚀" %>
          </button>

        </form>
      </div>
    </div>
    """
  end

  defp get_room_counts do
    @rooms
    |> Enum.map(fn room ->
      count = Presence.list("room:#{room.id}") |> map_size()
      {room.id, count}
    end)
    |> Map.new()
  end
end
