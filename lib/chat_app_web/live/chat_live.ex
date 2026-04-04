defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view

  alias Phoenix.PubSub
  alias ChatAppWeb.Presence

  @topic "chat_room"
  @max_length 280
  @max_members 3
  def mount(params, _session, socket) do
    username = params["username"] || "anon"
   is_audience =
  if connected?(socket) do
    PubSub.subscribe(ChatApp.PubSub, @topic)

    current_count = Presence.list(@topic) |> map_size()

    if current_count < @max_members do
      Presence.track(self(), @topic, username, %{
        online_at: System.system_time(:second)
      })
      false   # is NOT audience
    else
      true    # IS audience, don't track in Presence
    end
  else
    false
  end

{:ok,
 assign(socket,
  username: username,
  room: "general",
  message: "",
  messages: [],
  users: [],
  remaining: @max_length,
  is_audience: is_audience
)}
  end

  def handle_event("send", %{"message" => msg}, socket) do
  if not socket.assigns.is_audience and String.length(msg) <= @max_length and msg != "" do
      message = %{
        user: socket.assigns.username,
        body: msg
      }
    PubSub.broadcast(ChatApp.PubSub, @topic, {:new_msg, message})
      {:noreply,
      assign(socket, message: "", remaining: @max_length)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_message", %{"message" => msg}, socket) do
    remaining = @max_length - String.length(msg)
    {:noreply,
    assign(socket,
    message: msg,
    remaining: remaining
    )}
  end

  def handle_info({:new_msg, message}, socket) do
    {:noreply,
      update(socket, :messages, fn msgs -> msgs ++ [message]
    end)}
  end

  def handle_info(
      %Phoenix.Socket.Broadcast{
        event: "presence_diff",
        payload: %{joins: _joins, leaves: _leaves}
      },
      socket
    ) do
  users = Presence.list(@topic)
          |> Map.keys()
      {:noreply, assign(socket, users: users)}
    end
end
