defmodule ChatAppWeb.JoinLive do
  use ChatAppWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-100 to-indigo-200">
      <div class="bg-white shadow-2xl rounded-2xl p-8 w-full max-w-md">
        <h1 class="text-2xl font-bold text-center text-gray-800 mb-2">
          💬 Welcome to Chat
        </h1>
        <p class="text-center text-gray-500 mb-6">
          Enter your name to join the conversation
        </p>
        <form phx-submit="join" class="flex flex-col gap-4">
          <input
            type="text"
            name="username"
            placeholder="Enter your name..."
            class="border border-gray-300 rounded-lg p-3 focus:outline-none focus:ring-2 focus:ring-blue-400"
          />
          <button
            type="submit"
            class="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-3 rounded-lg transition"
          >
            Join Chat
          </button>
        </form>
      </div>
    </div>
    """
  end

  def handle_event("join", %{"username" => name}, socket) do
    unique_id = :rand.uniform(9999)
    unique_name = "#{name}-#{unique_id}"
    {:noreply,
     push_navigate(socket,
       to: "/chat?username=#{unique_name}"
     )}
  end
end