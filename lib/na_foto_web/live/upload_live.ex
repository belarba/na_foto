defmodule NaFotoWeb.UploadLive do
  use NaFotoWeb, :live_view

  alias NaFoto.Analyzer

  @max_file_size 15_000_000
  @accepted_types ~w(.jpg .jpeg .png .webp .heic .heif)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:result, nil)
     |> assign(:analyzing, false)
     |> assign(:error, nil)
     |> assign(:uploaded_image, nil)
     |> assign(:annotations, [])
     |> assign(:is_mobile, false)
     |> allow_upload(:photo,
       accept: @accepted_types,
       max_entries: 1,
       max_file_size: @max_file_size
     )}
  end

  @impl true
  def handle_event("mobile_detected", %{"is_mobile" => is_mobile}, socket) do
    {:noreply, assign(socket, :is_mobile, is_mobile)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("analyze", _params, socket) do
    case uploaded_entries(socket, :photo) do
      {[_entry | _], _} ->
        socket =
          socket
          |> assign(:analyzing, true)
          |> assign(:error, nil)
          |> assign(:result, nil)

        try do
          # Consume the upload
          [{image_binary, filename}] =
            consume_uploaded_entries(socket, :photo, fn %{path: path}, entry ->
              binary = File.read!(path)
              {:ok, {binary, entry.client_name}}
            end)

          # Store a resized preview
          preview_base64 =
            try do
              generate_preview(image_binary)
            rescue
              _ -> Base.encode64(image_binary)
            end

          socket = assign(socket, :uploaded_image, "data:image/jpeg;base64,#{preview_base64}")

          # Run analysis async with crash protection
          lv = self()

          Task.start(fn ->
            result =
              try do
                Analyzer.analyze(image_binary, filename)
              rescue
                e -> {:error, "Erro inesperado: #{Exception.message(e)}"}
              catch
                kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
              end

            send(lv, {:analysis_complete, result})
          end)

          # Safety timeout
          Process.send_after(self(), :analysis_timeout, 120_000)

          {:noreply, socket}
        rescue
          e ->
            {:noreply,
             socket
             |> assign(:analyzing, false)
             |> assign(:error, "Erro ao processar ficheiro: #{Exception.message(e)}")}
        end

      _ ->
        {:noreply, assign(socket, :error, "Por favor seleciona uma foto primeiro.")}
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(:result, nil)
     |> assign(:analyzing, false)
     |> assign(:error, nil)
     |> assign(:uploaded_image, nil)}
  end

  @arrow_colors %{
    "céu" => "#38BDF8",
    "água" => "#3B82F6",
    "natureza" => "#22C55E",
    "construções" => "#A8A29E",
    "estrada" => "#6B7280",
    "pessoas" => "#FBBF24",
    "veículos" => "#F87171",
    "interior" => "#FB923C"
  }

  @impl true
  def handle_info({:analysis_complete, {:ok, analysis}}, socket) do
    # Build annotations using real centroids from segmentation
    centroids = NaFoto.Analyzer.get_centroids(analysis)

    annotations =
      analysis.segmentation
      |> Enum.sort_by(fn {_k, v} -> v end, :desc)
      |> Enum.map(fn {category, percentage} ->
        {cx, cy} = Map.get(centroids, category, {50.0, 50.0})

        %{
          category: category,
          percentage: percentage,
          cx: cx,
          cy: cy,
          color: Map.get(@arrow_colors, category, "#A1A1AA")
        }
      end)
      |> spread_labels()

    {:noreply,
     socket
     |> assign(:result, analysis)
     |> assign(:annotations, annotations)
     |> assign(:analyzing, false)}
  end

  @impl true
  def handle_info({:analysis_complete, {:error, :selfie_detected}}, socket) do
    {:noreply,
     socket
     |> assign(:analyzing, false)
     |> assign(:error, "Esta foto parece ser uma selfie. Este projeto analisa paisagens e cenas urbanas/naturais. Por favor envia uma foto diferente.")}
  end

  @impl true
  def handle_info({:analysis_complete, {:error, :model_not_loaded}}, socket) do
    {:noreply,
     socket
     |> assign(:analyzing, false)
     |> assign(:error, "O modelo de segmentação não está carregado. Corre: mix run priv/scripts/download_model.exs")}
  end

  @impl true
  def handle_info({:analysis_complete, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:analyzing, false)
     |> assign(:error, "Erro na análise: #{inspect(reason)}")}
  end

  @impl true
  def handle_info(:analysis_timeout, socket) do
    if socket.assigns.analyzing do
      {:noreply,
       socket
       |> assign(:analyzing, false)
       |> assign(:error, "A análise demorou demasiado. Tenta com uma foto mais pequena ou noutro formato.")}
    else
      {:noreply, socket}
    end
  end

  defp mime_for_ext(".jpg"), do: "image/jpeg"
  defp mime_for_ext(".jpeg"), do: "image/jpeg"
  defp mime_for_ext(".png"), do: "image/png"
  defp mime_for_ext(".webp"), do: "image/webp"
  defp mime_for_ext(_), do: "image/jpeg"

  defp sort_map(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {_k, v} -> v end, :desc)
  end

  # Spread label Y positions so they don't overlap, while keeping dots at centroids
  defp spread_labels(annotations) do
    count = length(annotations)
    gap = if count > 5, do: 10, else: 14

    # Sort by centroid Y
    sorted = Enum.sort_by(annotations, & &1.cy)

    # First pass: push labels down to avoid overlap
    {pushed, _} =
      Enum.map_reduce(sorted, -100.0, fn ann, prev_y ->
        label_y = max(ann.cy, prev_y + gap)
        {Map.put(ann, :label_y, label_y), label_y}
      end)

    # Second pass (reverse): pull labels up if they exceed 95%
    {pulled, _} =
      pushed
      |> Enum.reverse()
      |> Enum.map_reduce(105.0, fn ann, next_y ->
        label_y = min(ann.label_y, next_y - gap)
        label_y = max(label_y, 2.0)
        {Map.put(ann, :label_y, Float.round(label_y, 1)), label_y}
      end)

    Enum.reverse(pulled)
  end

  @preview_max 600
  defp generate_preview(image_binary) do
    try do
      # Decode with Evision, resize, convert to Nx, encode with StbImage
      mat = Evision.imdecode(image_binary, Evision.Constant.cv_IMREAD_COLOR())
      {h, w, _} = Evision.Mat.shape(mat)

      scale = min(@preview_max / w, @preview_max / h)

      resized =
        if scale < 1.0 do
          Evision.resize(mat, {round(w * scale), round(h * scale)})
        else
          mat
        end

      # Convert BGR to RGB for StbImage
      rgb = Evision.cvtColor(resized, Evision.Constant.cv_COLOR_BGR2RGB())
      nx_tensor = Evision.Mat.to_nx(rgb, Nx.BinaryBackend)

      img = StbImage.from_nx(nx_tensor)
      jpeg_binary = StbImage.to_binary(img, :jpg)
      Base.encode64(jpeg_binary)
    rescue
      _ ->
        # Fallback: try to encode a very small version
        Base.encode64(image_binary)
    end
  end

  defp truncate_name(name) when byte_size(name) > 20 do
    ext = Path.extname(name)
    base = Path.basename(name, ext)
    String.slice(base, 0, 14) <> "..." <> ext
  end

  defp truncate_name(name), do: name

  defp color_css("vermelho"), do: "#EF4444"
  defp color_css("laranja"), do: "#F97316"
  defp color_css("amarelo"), do: "#EAB308"
  defp color_css("verde"), do: "#22C55E"
  defp color_css("azul"), do: "#3B82F6"
  defp color_css("roxo"), do: "#A855F7"
  defp color_css("castanho"), do: "#92400E"
  defp color_css("cinzento"), do: "#9CA3AF"
  defp color_css("branco"), do: "#E5E7EB"
  defp color_css("preto"), do: "#1F2937"
  defp color_css(_), do: "#6B7280"

  defp upload_error_to_string(:too_large), do: "FICHEIRO DEMASIADO GRANDE (MAX 10MB)"
  defp upload_error_to_string(:too_many_files), do: "APENAS UMA FOTO DE CADA VEZ"
  defp upload_error_to_string(:not_accepted), do: "FORMATO NAO ACEITE. USA JPG, PNG OU WEBP"
  defp upload_error_to_string(err), do: "ERRO: #{inspect(err)}"
end
