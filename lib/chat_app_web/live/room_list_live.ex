defmodule ChatAppWeb.RoomListLive do
  use ChatAppWeb, :live_view
  alias ChatAppWeb.Presence

  @rooms [
    %{id: "lobby",  name: "Lobby",  emoji: "🏠", desc: "General chat"},
    %{id: "tamil",  name: "Tamil",  emoji: "🗣️", desc: "Tamil la pesalaam"},
    %{id: "gaming", name: "Gaming", emoji: "🎮", desc: "Games and fun"}
  ]

  @max_members 3

  def mount(_params, _session, socket) do
    room_counts = get_room_counts()

    if connected?(socket) do
      Enum.each(@rooms, fn room ->
        Phoenix.PubSub.subscribe(ChatApp.PubSub, "room:#{room.id}")
      end)
    end

    {:ok,
     assign(socket,
       rooms: @rooms,
       room_counts: room_counts,
       max_members: @max_members
     )}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff", topic: topic},
        socket
      ) do
    room_id   = String.replace_prefix(topic, "room:", "")
    new_count = Presence.list(topic) |> map_size()
    updated   = Map.put(socket.assigns.room_counts, room_id, new_count)
    {:noreply, assign(socket, room_counts: updated)}
  end

  def handle_event("enter_room", %{"room" => room_id}, socket) do
    {:noreply, push_navigate(socket, to: "/join?room=#{room_id}")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-6">
      <div class="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-lg">

        <h1 class="text-3xl font-bold text-center text-gray-800 mb-2">
          💬 Chat Rooms
        </h1>
        <p class="text-center text-gray-400 mb-8">
          Choose a room to join
        </p>

        <div class="flex flex-col gap-4">

          <%= for room <- @rooms do %>
            <% count   = Map.get(@room_counts, room.id, 0) %>
            <% is_full = count >= @max_members %>

            <div class="rounded-xl border border-gray-200 p-5">
              <div class="flex items-center justify-between gap-4">

                <!-- Left side: emoji + name + desc -->
                <div class="flex items-center gap-4">
                  <span class="text-4xl"><%= room.emoji %></span>
                  <div>
                    <p class="font-bold text-gray-800 text-lg">
                      <%= room.name %>
                    </p>
                    <p class="text-gray-400 text-sm">
                      <%= room.desc %>
                    </p>
                  </div>
                </div>

                <!-- Right side: count + bar + button -->
                <div class="flex flex-col items-end gap-2">

                  <!-- Member count text -->
                  <%= if is_full do %>
                    <p class="text-red-500 text-sm font-semibold">
                      <%= count %>/<%= @max_members %> full
                    </p>
                  <% else %>
                    <p class="text-green-600 text-sm font-semibold">
                      <%= count %>/<%= @max_members %> members
                    </p>
                  <% end %>

                  <!-- Progress bar -->
                  <div class="w-24 h-2 bg-gray-200 rounded-full">
                    <%= if is_full do %>
                      <div class="h-2 rounded-full bg-red-400 w-full"></div>
                    <% else %>
                      <div
                        class="h-2 rounded-full bg-green-400"
                        style={"width: #{trunc(count * 100 / @max_members)}%"}
                      >
                      </div>
                    <% end %>
                  </div>

                  <!-- Enter button — phx-click use பண்றோம், <a> இல்ல -->
                  <%= if is_full do %>
                    <button
                      phx-click="enter_room"
                      phx-value-room={room.id}
                      class="px-4 py-2 rounded-lg text-sm font-semibold bg-orange-100 text-orange-700"
                    >
                      👀 Audience
                    </button>
                  <% else %>
                    <button
                      phx-click="enter_room"
                      phx-value-room={room.id}
                      class="px-4 py-2 rounded-lg text-sm font-semibold bg-blue-500 text-white"
                    >
                      Enter →
                    </button>
                  <% end %>

                </div>
                <!-- END right side -->

              </div>
            </div>
            <!-- END room card -->

          <% end %>

        </div>
        <!-- END rooms list -->

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
