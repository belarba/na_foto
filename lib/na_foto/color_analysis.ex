defmodule NaFoto.ColorAnalysis do
  @moduledoc """
  Analyzes color distribution in an image using Evision (OpenCV).
  Returns percentage of each color category and top dominant colors via K-means.
  """

  alias Evision, as: Cv

  # HSV ranges for color classification
  # H: 0-179, S: 0-255, V: 0-255 in OpenCV
  @color_ranges [
    {:vermelho,   [{0, 10}, {100, 255}, {50, 255}]},
    {:vermelho2,  [{170, 179}, {100, 255}, {50, 255}]},
    {:laranja,    [{10, 25}, {100, 255}, {50, 255}]},
    {:amarelo,    [{25, 35}, {100, 255}, {50, 255}]},
    {:verde,      [{35, 85}, {50, 255}, {40, 255}]},
    {:azul,       [{85, 130}, {50, 255}, {40, 255}]},
    {:roxo,       [{130, 170}, {50, 255}, {40, 255}]},
    {:branco,     [{0, 179}, {0, 50}, {200, 255}]},
    {:preto,      [{0, 179}, {0, 255}, {0, 50}]},
    {:cinzento,   [{0, 179}, {0, 50}, {50, 200}]}
  ]

  @doc """
  Analyzes an image file and returns color distribution.
  Returns {:ok, %{colors: %{}, dominant_colors: [%{}]}} or {:error, reason}
  """
  def analyze(image_path) when is_binary(image_path) do
    case Cv.imread(image_path) do
      %Cv.Mat{} = img ->
        colors = classify_colors(img)
        dominant = extract_dominant_colors(img, 5)
        {:ok, %{colors: colors, dominant_colors: dominant}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @analysis_size 300

  def analyze_binary(binary) when is_binary(binary) do
    case Cv.imdecode(binary, Cv.Constant.cv_IMREAD_COLOR()) do
      %Cv.Mat{} = img ->
        # Resize for performance — color analysis doesn't need full resolution
        small = Cv.resize(img, {@analysis_size, @analysis_size})
        colors = classify_colors(small)
        dominant = extract_dominant_colors(small, 5)
        {:ok, %{colors: colors, dominant_colors: dominant}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp classify_colors(img) do
    hsv = Cv.cvtColor(img, Cv.Constant.cv_COLOR_BGR2HSV())
    {h, w, _} = get_shape(hsv)
    total_pixels = h * w

    # Convert to Nx binary for fast channel slicing
    hsv_binary = Cv.Mat.to_nx(hsv, Nx.BinaryBackend) |> Nx.to_binary()

    # Process all HSV triplets in one pass via binary (much faster than Nx)
    counts = count_colors_from_binary(hsv_binary)

    # Convert to percentages
    counts
    |> Enum.map(fn {name, count} ->
      percentage = Float.round(count / total_pixels * 100, 1)
      {Atom.to_string(name), percentage}
    end)
    |> Enum.filter(fn {_name, pct} -> pct > 0.1 end)
    |> Enum.sort_by(fn {_name, pct} -> pct end, :desc)
    |> Map.new()
  end

  defp count_colors_from_binary(binary) do
    for <<h_val::8, s_val::8, v_val::8 <- binary>>, reduce: %{} do
      acc ->
        color = classify_pixel(h_val, s_val, v_val)
        Map.update(acc, color, 1, &(&1 + 1))
    end
  end

  defp classify_pixel(h, s, v) do
    cond do
      v < 50 -> :preto
      s < 50 and v >= 200 -> :branco
      s < 50 -> :cinzento
      h <= 10 or h >= 170 -> :vermelho
      h > 10 and h <= 25 -> :laranja
      h > 25 and h <= 35 -> :amarelo
      h > 35 and h <= 85 -> :verde
      h > 85 and h <= 130 -> :azul
      h > 130 and h < 170 -> :roxo
      true -> :cinzento
    end
  end

  defp extract_dominant_colors(img, k) do
    # img is already resized to @analysis_size
    {h, w, _} = get_shape(img)
    small = img

    # Reshape to list of pixels (use BinaryBackend for slice support)
    pixels = Cv.Mat.to_nx(small, Nx.BinaryBackend)
    flat = Nx.reshape(pixels, {h * w, 3})

    # Convert to float32 for kmeans
    data = Nx.as_type(flat, :f32) |> Cv.Mat.from_nx()

    # K-means clustering
    # TermCriteria: type=EPS+MAX_ITER (1+2=3), max_count=10, epsilon=1.0
    criteria = {3, 10, 1.0}

    # bestLabels: empty Mat as placeholder
    best_labels = Cv.Mat.empty()

    {_compactness, labels, centers} =
      Cv.kmeans(data, k, best_labels, criteria, 3, Cv.Constant.cv_KMEANS_PP_CENTERS())

    labels_nx = Cv.Mat.to_nx(labels, Nx.BinaryBackend) |> Nx.flatten()
    centers_nx = Cv.Mat.to_nx(centers, Nx.BinaryBackend)
    total = Nx.size(labels_nx)

    0..(k - 1)
    |> Enum.map(fn i ->
      count = labels_nx |> Nx.equal(i) |> Nx.sum() |> Nx.to_number()
      percentage = Float.round(count / total * 100, 1)

      # BGR to RGB
      b = centers_nx[i][0] |> Nx.to_number() |> round()
      g = centers_nx[i][1] |> Nx.to_number() |> round()
      r = centers_nx[i][2] |> Nx.to_number() |> round()

      hex =
        "#" <>
        String.pad_leading(Integer.to_string(r, 16), 2, "0") <>
        String.pad_leading(Integer.to_string(g, 16), 2, "0") <>
        String.pad_leading(Integer.to_string(b, 16), 2, "0")

      %{"hex" => String.upcase(hex), "rgb" => [r, g, b], "percentage" => percentage}
    end)
    |> Enum.sort_by(& &1["percentage"], :desc)
  end

  defp get_shape(mat) do
    shape = Cv.Mat.shape(mat)
    case shape do
      {h, w, c} -> {h, w, c}
      {h, w} -> {h, w, 1}
    end
  end
end
