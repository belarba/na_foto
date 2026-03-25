defmodule NaFoto.ML.ModelServer do
  @moduledoc """
  GenServer that loads and holds the SegFormer ONNX model in memory.
  """
  use GenServer

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_model do
    GenServer.call(__MODULE__, :get_model, 30_000)
  end

  @impl true
  def init(_) do
    model_path = model_path()

    if File.exists?(model_path) do
      Logger.info("Loading SegFormer ONNX model from #{model_path}...")
      model = Ortex.load(model_path)
      Logger.info("SegFormer model loaded successfully.")
      {:ok, %{model: model}}
    else
      Logger.warning("Model not found at #{model_path}. Run: mix run priv/scripts/download_model.exs")
      {:ok, %{model: nil}}
    end
  end

  @impl true
  def handle_call(:get_model, _from, %{model: model} = state) do
    {:reply, model, state}
  end

  defp model_path do
    Path.join(:code.priv_dir(:na_foto), "models/segformer-b0-ade.onnx")
  end
end
