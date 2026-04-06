defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view

  alias Phoenix.PubSub
  alias ChatAppWeb.Presence

  @max_length 280
  @max_members 3

  # =====================
  # MOUNT
  # =====================
  def mount(params, _session, socket) do
    username = params["username"] || "anon"
    room     = params["room"] || "lobby"      # FIX 1: params-லிருந்து எடு
    topic    = "room:#{room}"                 # FIX 2: dynamic topic

    is_audience =
      if connected?(socket) do
        PubSub.subscribe(ChatApp.PubSub, topic)

        current_count = Presence.list(topic) |> map_size()

        if current_count < @max_members do
          Presence.track(self(), topic, username, %{
            online_at: System.system_time(:second)
          })
          false   # member
        else
          true    # audience
        end
      else
        false
      end

    {:ok,
     assign(socket,
       username:    username,
       room:        room,         # "lobby" / "tamil" / "gaming"
       topic:       topic,        # "room:lobby" etc
       message:     "",
       messages:    [],
       users:       [],
       remaining:   @max_length,
       is_audience: is_audience
     )}
  end

  # =====================
  # EVENTS
  # =====================

  def handle_event("send", %{"message" => msg}, socket) do
    if not socket.assigns.is_audience and
         String.length(msg) <= @max_length and
         msg != "" do

      message = %{
        user: socket.assigns.username,
        body: msg
      }

      PubSub.broadcast(ChatApp.PubSub, socket.assigns.topic, {:new_msg, message})

      {:noreply, assign(socket, message: "", remaining: @max_length)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_message", %{"message" => msg}, socket) do
    {:noreply,
     assign(socket,
       message:   msg,
       remaining: @max_length - String.length(msg)
     )}
  end

  # =====================
  # INFO (PubSub messages)
  # =====================

  # New message வந்தா messages list-ல add பண்று
  def handle_info({:new_msg, message}, socket) do
    {:noreply, update(socket, :messages, fn msgs -> msgs ++ [message] end)}
  end

  # யாராவது join/leave ஆனா users list update பண்று
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff"},
        socket
      ) do
    users = Presence.list(socket.assigns.topic) |> Map.keys()  # FIX 3: socket.assigns.topic
    {:noreply, assign(socket, users: users)}
  end
end
