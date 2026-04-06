defmodule ChatAppWeb.JoinLive do
  use ChatAppWeb, :live_view
  alias Phoenix.PubSub
  alias ChatAppWeb.Presence

  @max_members 3

  def mount(params, _session, socket) do
    room  = params["room"] || "lobby"     # room list-லிருந்து வருது
    topic = "room:#{room}"               # dynamic topic!

    if connected?(socket) do
      PubSub.subscribe(ChatApp.PubSub, topic)
    end

    member_count = Presence.list(topic) |> map_size()

    {:ok,
     assign(socket,
       room: room,
       topic: topic,
       member_count: member_count,
       max_members: @max_members
     )}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff"},
        socket
      ) do
    member_count = Presence.list(socket.assigns.topic) |> map_size()
    {:noreply, assign(socket, member_count: member_count)}
  end

  def handle_event("join", %{"username" => name}, socket) do
    unique_id   = :rand.uniform(9999)
    unique_name = "#{name}-#{unique_id}"
    {:noreply,
     push_navigate(socket,
       to: "/chat?room=#{socket.assigns.room}&username=#{unique_name}"
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-100 to-indigo-200">
      <div class="bg-white shadow-2xl rounded-2xl p-8 w-full max-w-md">

        <!-- Back link -->
        <a href="/" class="text-blue-400 text-sm mb-6 inline-block hover:underline">
          ← Back to rooms
        </a>

        <h1 class="text-2xl font-bold text-center text-gray-800 mb-1">
          💬 Join Chat
        </h1>
        <p class="text-center text-gray-500 mb-4">
          Room: <strong class="text-blue-600"><%= String.capitalize(@room) %></strong>
        </p>

        <!-- Live member count badge -->
        <div class="flex justify-center mb-6">
          <%= if @member_count >= @max_members do %>
            <span class="bg-orange-100 text-orange-700 text-sm font-medium px-4 py-1 rounded-full">
              🔴 Room full · <%= @member_count %>/<%= @max_members %> · Joining as audience
            </span>
          <% else %>
            <span class="bg-green-100 text-green-700 text-sm font-medium px-4 py-1 rounded-full">
              🟢 <%= @member_count %>/<%= @max_members %> members joined
            </span>
          <% end %>
        </div>

        <form phx-submit="join" class="flex flex-col gap-4">
          <input
            type="text"
            name="username"
            placeholder="Enter your name..."
            required
            class="border border-gray-300 rounded-lg p-3 focus:outline-none focus:ring-2 focus:ring-blue-400"
          />
          <button
            type="submit"
            class="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-3 rounded-lg transition"
          >
            <%= if @member_count >= @max_members, do: "Join as Audience 👀", else: "Join Chat 🚀" %>
          </button>
        </form>

      </div>
    </div>
    """
  end
end
