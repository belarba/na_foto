defmodule NaFotoWeb.AboutLive do
  use NaFotoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-8">
      <header class="flex items-center justify-between mb-10">
        <h1 class="font-pixel text-xl md:text-2xl text-emerald-400 drop-shadow-[2px_2px_0_rgba(0,0,0,0.8)]">
          &gt; ABOUT
        </h1>
        <.link navigate="/" class="font-pixel text-[10px] text-amber-400 hover:text-amber-300 pixel-glow">
          [VOLTAR]
        </.link>
      </header>

      <%!-- ABOUT --%>
      <div class="pixel-border border-zinc-600 bg-zinc-900/80 p-6 mb-6">
        <h2 class="font-pixel text-sm text-emerald-400 mb-4">&gt; O QUE E</h2>
        <div class="font-silk text-zinc-300 text-sm space-y-3 leading-relaxed">
          <p>
            NA FOTO e uma aplicacao que analisa fotografias usando
            inteligencia artificial para identificar o que esta na imagem.
          </p>
          <p>
            Usa o modelo SEGFORMER (NVIDIA) treinado no dataset ADE20K
            para classificar cada pixel da foto em categorias como
            ceu, construcoes, natureza, agua, estrada, pessoas e veiculos.
          </p>
          <p>
            Alem da segmentacao semantica, analisa a distribuicao de
            cores e extrai a paleta dominante da imagem.
          </p>
          <p>
            Todo o processamento e feito localmente no servidor.
            Nenhuma API externa e utilizada.
          </p>
        </div>
      </div>

      <%!-- STACK --%>
      <div class="pixel-border border-zinc-600 bg-zinc-900/80 p-6 mb-6">
        <h2 class="font-pixel text-sm text-fuchsia-400 mb-4">&gt; STACK</h2>
        <div class="font-silk text-zinc-300 text-xs space-y-2">
          <p><span class="text-emerald-400">ELIXIR</span> + <span class="text-emerald-400">PHOENIX LIVEVIEW</span> - WEB FRAMEWORK</p>
          <p><span class="text-emerald-400">SEGFORMER-B0-ADE20K</span> - MODELO DE SEGMENTACAO (ONNX)</p>
          <p><span class="text-emerald-400">EVISION/OPENCV</span> - ANALISE DE CORES + DETECAO FACIAL</p>
          <p><span class="text-emerald-400">SQLITE</span> - PERSISTENCIA DE DADOS ESTATISTICOS</p>
        </div>
      </div>

      <%!-- PRIVACIDADE / TERMOS --%>
      <div class="pixel-border border-zinc-600 bg-zinc-900/80 p-6 mb-6">
        <h2 class="font-pixel text-sm text-amber-400 mb-4">&gt; PRIVACIDADE</h2>
        <div class="font-silk text-zinc-300 text-sm space-y-3 leading-relaxed">
          <p>
            <span class="text-emerald-400">AS TUAS FOTOS NAO SAO ARMAZENADAS.</span>
            A imagem e processada em memoria e descartada imediatamente
            apos a analise. Nao guardamos, partilhamos ou transmitimos
            as tuas fotografias.
          </p>
          <p>
            Apenas os dados estatisticos resultantes da analise sao
            guardados (percentagens de categorias, distribuicao de
            cores, paleta dominante). Estes dados nao permitem
            reconstruir ou identificar a imagem original.
          </p>
          <p>
            O filtro de selfies usa detecao facial apenas para rejeitar
            fotos com rostos grandes. Nenhum dado biometrico e armazenado
            ou processado para alem desta verificacao temporaria.
          </p>
          <p>
            Todo o processamento e feito no nosso servidor.
            Nenhuma imagem ou dado e enviado para servicos de terceiros.
          </p>
        </div>
      </div>

      <%!-- TERMOS --%>
      <div class="pixel-border border-zinc-600 bg-zinc-900/80 p-6 mb-6">
        <h2 class="font-pixel text-sm text-amber-400 mb-4">&gt; TERMOS DE USO</h2>
        <div class="font-silk text-zinc-300 text-sm space-y-3 leading-relaxed">
          <p>
            Este servico e fornecido "tal como esta", sem garantias.
            Os resultados da analise sao aproximacoes geradas por um
            modelo de IA e podem nao ser 100% precisos.
          </p>
          <p>
            Ao utilizar este servico, aceitas que:
          </p>
          <ul class="list-none space-y-2 ml-2">
            <li><span class="text-emerald-400">&gt;</span> As fotos enviadas nao sao armazenadas</li>
            <li><span class="text-emerald-400">&gt;</span> Os resultados sao indicativos e nao definitivos</li>
            <li><span class="text-emerald-400">&gt;</span> O servico pode ser descontinuado a qualquer momento</li>
            <li><span class="text-emerald-400">&gt;</span> Selfies e fotos com rostos dominantes sao rejeitadas</li>
          </ul>
        </div>
      </div>

      <footer class="text-center mt-8">
        <p class="font-pixel text-[8px] text-zinc-700">
          FEITO COM ELIXIR + PHOENIX + SEGFORMER AI
        </p>
      </footer>
    </div>
    """
  end
end
