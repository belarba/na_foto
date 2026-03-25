defmodule NaFoto.Analyses.Analysis do
  use Ecto.Schema
  import Ecto.Changeset

  schema "analyses" do
    field :filename, :string
    field :file_hash, :string
    field :width, :integer
    field :height, :integer
    field :segmentation, :map, default: %{}
    field :colors, :map, default: %{}
    field :dominant_colors, {:array, :map}, default: []
    field :metadata, :map, default: %{}

    timestamps()
  end

  def changeset(analysis, attrs) do
    analysis
    |> cast(attrs, [:filename, :file_hash, :width, :height, :segmentation, :colors, :dominant_colors, :metadata])
    |> validate_required([:filename, :file_hash, :width, :height])
  end
end
