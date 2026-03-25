defmodule NaFoto.Segmentation do
  @moduledoc """
  Semantic segmentation using SegFormer-B0-ADE20K via Ortex (ONNX Runtime).
  Returns percentage of each semantic category in the image,
  plus anchor positions for annotation overlays.
  """

  alias NaFoto.ML.{ModelServer, Preprocessing, ADE20KLabels}

  # Grid subdivision for finding dense regions
  @block_size 16

  def analyze(image_binary) when is_binary(image_binary) do
    model = ModelServer.get_model()

    if model == nil do
      {:error, :model_not_loaded}
    else
      do_analyze(model, image_binary)
    end
  end

  defp do_analyze(model, image_binary) do
    {input_tensor, {orig_h, orig_w}} = Preprocessing.preprocess(image_binary)

    input_binary = Nx.backend_transfer(input_tensor, Nx.BinaryBackend)
    {logits} = Ortex.run(model, input_binary)
    logits = Nx.backend_transfer(logits, Nx.BinaryBackend)

    # logits shape: [1, 150, 128, 128] → predictions: [128, 128]
    predictions =
      logits
      |> Nx.argmax(axis: 1)
      |> Nx.squeeze(axes: [0])
      |> Nx.as_type(:u8)

    {grid_h, grid_w} = Nx.shape(predictions)
    flat = Nx.to_flat_list(predictions)
    total_pixels = length(flat)
    pixel_counts = Enum.frequencies(flat)

    # Build 2D grid: list of {class_idx, row, col}
    pixels_with_pos =
      flat
      |> Enum.with_index()
      |> Enum.map(fn {class_idx, idx} ->
        {class_idx, div(idx, grid_w), rem(idx, grid_w)}
      end)

    # Find anchor points: the densest block for each group
    anchors = compute_anchors(pixels_with_pos, grid_h, grid_w)

    segmentation = ADE20KLabels.group_percentages(pixel_counts, total_pixels)

    person_pixels = Map.get(pixel_counts, 12, 0)
    person_percentage = person_pixels / total_pixels * 100

    {:ok, %{
      segmentation: segmentation,
      centroids: anchors,
      person_percentage: person_percentage,
      original_size: {orig_h, orig_w},
      detailed: detailed_labels(pixel_counts, total_pixels)
    }}
  end

  # For each group, find the block (sub-region) with the highest density of that group,
  # then return the center of that block as the anchor point.
  defp compute_anchors(pixels_with_pos, grid_h, grid_w) do
    bs = @block_size
    blocks_y = div(grid_h, bs)
    blocks_x = div(grid_w, bs)

    # Count pixels per group per block: %{{group, block_row, block_col} => count}
    block_counts =
      Enum.reduce(pixels_with_pos, %{}, fn {class_idx, row, col}, acc ->
        group = ADE20KLabels.group_for(class_idx)
        br = min(div(row, bs), blocks_y - 1)
        bc = min(div(col, bs), blocks_x - 1)

        Map.update(acc, {group, br, bc}, 1, &(&1 + 1))
      end)

    # For each group, find the block with max count
    block_counts
    |> Enum.reduce(%{}, fn {{group, br, bc}, count}, acc ->
      case Map.get(acc, group) do
        nil ->
          Map.put(acc, group, {br, bc, count})

        {_best_br, _best_bc, best_count} when count > best_count ->
          Map.put(acc, group, {br, bc, count})

        _ ->
          acc
      end
    end)
    |> Map.new(fn {group, {br, bc, _count}} ->
      # Center of the densest block, as percentage
      cx = (bc * bs + bs / 2) / grid_w * 100
      cy = (br * bs + bs / 2) / grid_h * 100
      {group, {Float.round(cx, 1), Float.round(cy, 1)}}
    end)
  end

  defp detailed_labels(pixel_counts, total_pixels) do
    pixel_counts
    |> Enum.map(fn {class_idx, count} ->
      label = ADE20KLabels.label(class_idx)
      percentage = Float.round(count / total_pixels * 100, 1)
      {label, percentage}
    end)
    |> Enum.filter(fn {_label, pct} -> pct > 0.5 end)
    |> Enum.sort_by(fn {_label, pct} -> pct end, :desc)
    |> Map.new()
  end
end
