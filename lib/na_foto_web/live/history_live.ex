defmodule NaFotoWeb.HistoryLive do
  use NaFotoWeb, :live_view

  alias NaFoto.Analyses

  @impl true
  def mount(_params, _session, socket) do
    analyses = Analyses.list_analyses()
    {:ok, assign(socket, :analyses, analyses)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <header class="flex items-center justify-between mb-8">
        <h1 class="font-pixel text-xl text-emerald-400 drop-shadow-[2px_2px_0_rgba(0,0,0,0.8)]">
          &gt; HISTORICO
        </h1>
        <.link navigate="/" class="font-pixel text-[10px] text-amber-400 hover:text-amber-300 pixel-glow">
          [NOVA ANALISE]
        </.link>
      </header>

      <div :if={@analyses == []} class="text-center py-16 pixel-border border-zinc-600 bg-zinc-900/50">
        <p class="font-silk text-zinc-500 text-sm">NENHUMA ANALISE ENCONTRADA.</p>
        <.link navigate="/" class="font-pixel text-[10px] text-emerald-400 hover:text-emerald-300 mt-4 inline-block pixel-glow">
          [COMECAR AGORA]
        </.link>
      </div>

      <div class="space-y-4">
        <div :for={analysis <- @analyses} class="pixel-border border-zinc-600 bg-zinc-900/80 p-4">
          <div>
            <p class="font-silk text-zinc-500 text-xs">
              <%= format_date(analysis.inserted_at) %> | <%= analysis.width %>&times;<%= analysis.height %>px
            </p>
          </div>

          <div :if={analysis.segmentation != %{}} class="mt-3">
            <div class="flex gap-2 flex-wrap">
              <span
                :for={{cat, pct} <- Enum.sort_by(analysis.segmentation, fn {_, v} -> v end, :desc)}
                class="font-silk text-xs bg-zinc-800 text-zinc-400 px-2 py-1 pixel-border-sm border-zinc-700"
              >
                <%= String.upcase(cat) %>: <%= pct %>%
              </span>
            </div>
          </div>

          <div :if={analysis.dominant_colors != []} class="mt-3 flex gap-2 flex-wrap">
            <div
              :for={color <- analysis.dominant_colors}
              class="w-6 h-6 pixel-swatch"
              title={"#{color["hex"]} (#{color["percentage"]}%)"}
              style={"background-color: #{color["hex"]}"}
            >
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %H:%M")
  end
end
