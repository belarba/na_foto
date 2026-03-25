defmodule NaFoto.ML.Preprocessing do
  @moduledoc """
  Image preprocessing for SegFormer model inference.
  Uses Evision for resize (fast), minimal Nx for normalization.
  """

  alias Evision, as: Cv

  @target_size 512

  @doc """
  Preprocesses an image binary for SegFormer inference.
  Returns {input_tensor, {original_height, original_width}}.
  """
  def preprocess(image_binary) when is_binary(image_binary) do
    # Decode and resize with Evision (fast native C++)
    mat = Cv.imdecode(image_binary, Cv.Constant.cv_IMREAD_COLOR())
    {h, w, _} = Cv.Mat.shape(mat)

    resized = Cv.resize(mat, {@target_size, @target_size})
    rgb = Cv.cvtColor(resized, Cv.Constant.cv_COLOR_BGR2RGB())

    # Convert to Nx binary tensor - shape {512, 512, 3}, type u8
    nx_u8 = Cv.Mat.to_nx(rgb, Nx.BinaryBackend)

    # Get the raw binary data and do normalization manually for speed
    # Convert u8 -> f32, normalize with ImageNet mean/std in one pass
    raw = Nx.to_binary(nx_u8)
    mean = {0.485, 0.456, 0.406}
    std = {0.229, 0.224, 0.225}

    # Process all pixels: normalize and transpose HWC -> CHW
    size = @target_size * @target_size
    {r_data, g_data, b_data} = normalize_channels(raw, mean, std, size)

    # Build NCHW tensor: {1, 3, 512, 512}
    nchw_binary = r_data <> g_data <> b_data
    input = Nx.from_binary(nchw_binary, :f32) |> Nx.reshape({1, 3, @target_size, @target_size})

    {input, {h, w}}
  end

  defp normalize_channels(raw_bytes, {mean_r, mean_g, mean_b}, {std_r, std_g, std_b}, pixel_count) do
    # Process RGB triplets into separate normalized channel binaries
    {r_acc, g_acc, b_acc} =
      for <<r::8, g::8, b::8 <- raw_bytes>>, reduce: {<<>>, <<>>, <<>>} do
        {r_acc, g_acc, b_acc} ->
          nr = (r / 255.0 - mean_r) / std_r
          ng = (g / 255.0 - mean_g) / std_g
          nb = (b / 255.0 - mean_b) / std_b

          {
            <<r_acc::binary, nr::float-32-native>>,
            <<g_acc::binary, ng::float-32-native>>,
            <<b_acc::binary, nb::float-32-native>>
          }
      end

    {r_acc, g_acc, b_acc}
  end
end
