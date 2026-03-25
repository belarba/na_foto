# Script to download the SegFormer-B0-ADE20K ONNX model from HuggingFace
#
# Usage: mix run priv/scripts/download_model.exs

model_dir = Path.join(:code.priv_dir(:na_foto), "models")
File.mkdir_p!(model_dir)
model_path = Path.join(model_dir, "segformer-b0-ade.onnx")

if File.exists?(model_path) do
  IO.puts("Model already exists at #{model_path}")
else
  # HuggingFace Xenova pre-exported ONNX model (publicly accessible)
  url = "https://huggingface.co/Xenova/segformer-b0-finetuned-ade-512-512/resolve/main/onnx/model.onnx"

  IO.puts("Downloading SegFormer-B0-ADE20K ONNX model...")
  IO.puts("From: #{url}")
  IO.puts("To: #{model_path}")

  response = Req.get!(url, receive_timeout: 300_000, redirect: true, max_redirects: 5)

  case response.status do
    200 ->
      File.write!(model_path, response.body)
      size_mb = byte_size(response.body) / (1024 * 1024)
      IO.puts("Download complete! Size: #{Float.round(size_mb, 1)} MB")

    status ->
      IO.puts("Failed to download model. HTTP status: #{status}")
      IO.puts("You may need to export the model manually using Python optimum:")
      IO.puts("  pip install optimum[exporters]")
      IO.puts("  optimum-cli export onnx --model nvidia/segformer-b0-finetuned-ade-512-512 segformer_onnx/")
      IO.puts("Then copy segformer_onnx/model.onnx to #{model_path}")
  end
end
