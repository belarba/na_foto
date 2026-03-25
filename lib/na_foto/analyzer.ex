defmodule NaFoto.Analyzer do
  @moduledoc """
  Orchestrates image analysis: selfie filter, segmentation, and color analysis.
  """

  alias NaFoto.{SelfieFilter, Segmentation, ColorAnalysis, Analyses}

  @person_threshold 30.0

  @doc """
  Analyzes an uploaded image.
  Returns {:ok, analysis} or {:error, reason}.
  """
  def analyze(image_binary, filename) when is_binary(image_binary) do
    file_hash = :crypto.hash(:sha256, image_binary) |> Base.encode16(case: :lower)

    # Check for cached result
    case Analyses.get_by_hash(file_hash) do
      %Analyses.Analysis{} = existing ->
        {:ok, existing}

      nil ->
        run_analysis(image_binary, filename, file_hash)
    end
  end

  defp run_analysis(image_binary, filename, file_hash) do
    # Step 1: Selfie filter (quick face detection)
    with :ok <- check_selfie(image_binary) do
      # Step 2: Run segmentation and color analysis in parallel
      seg_task = Task.async(fn -> Segmentation.analyze(image_binary) end)
      color_task = Task.async(fn -> ColorAnalysis.analyze_binary(image_binary) end)

      seg_result = Task.await(seg_task, 120_000)
      color_result = Task.await(color_task, 120_000)

      case {seg_result, color_result} do
        {{:ok, seg}, {:ok, colors}} ->
          # Double-check person percentage from segmentation
          if seg.person_percentage > @person_threshold do
            {:error, :selfie_detected}
          else
            save_result(filename, file_hash, seg, colors)
          end

        {{:error, :model_not_loaded}, {:ok, colors}} ->
          # Run without segmentation if model not loaded
          save_result_colors_only(filename, file_hash, colors, image_binary)

        {{:error, reason}, _} ->
          {:error, reason}

        {_, {:error, reason}} ->
          {:error, reason}
      end
    end
  end

  defp check_selfie(image_binary) do
    # Write to temp file for Evision face detection
    tmp_path = Path.join(System.tmp_dir!(), "na_foto_#{:rand.uniform(999_999)}.jpg")

    try do
      File.write!(tmp_path, image_binary)
      SelfieFilter.check(tmp_path)
    after
      File.rm(tmp_path)
    end
  end

  defp save_result(filename, file_hash, seg, colors) do
    attrs = %{
      filename: Path.basename(filename),
      file_hash: file_hash,
      width: elem(seg.original_size, 1),
      height: elem(seg.original_size, 0),
      segmentation: seg.segmentation,
      colors: colors.colors,
      dominant_colors: colors.dominant_colors,
      metadata: %{
        "detailed_segmentation" => seg.detailed,
        "centroids" => encode_centroids(seg.centroids)
      }
    }

    Analyses.create_analysis(attrs)
  end

  defp save_result_colors_only(filename, file_hash, colors, image_binary) do
    {:ok, img} = StbImage.read_binary(image_binary)
    {h, w, _} = img |> StbImage.to_nx() |> Nx.shape()

    attrs = %{
      filename: Path.basename(filename),
      file_hash: file_hash,
      width: w,
      height: h,
      segmentation: %{},
      colors: colors.colors,
      dominant_colors: colors.dominant_colors,
      metadata: %{"note" => "Segmentation model not loaded"}
    }

    Analyses.create_analysis(attrs)
  end

  defp encode_centroids(centroids) do
    Map.new(centroids, fn {group, {cx, cy}} ->
      {group, %{"cx" => cx, "cy" => cy}}
    end)
  end

  @doc """
  Extracts centroids from an analysis result (works with both fresh and cached).
  """
  def get_centroids(%{metadata: %{"centroids" => c}}) when is_map(c) do
    Map.new(c, fn {group, %{"cx" => cx, "cy" => cy}} -> {group, {cx, cy}} end)
  end

  def get_centroids(%{centroids: c}) when is_map(c), do: c
  def get_centroids(_), do: %{}
end
