defmodule NaFoto.Repo.Migrations.CreateAnalyses do
  use Ecto.Migration

  def change do
    create table(:analyses) do
      add :filename, :string, null: false
      add :file_hash, :string, null: false
      add :width, :integer, null: false
      add :height, :integer, null: false
      add :segmentation, :map, default: %{}
      add :colors, :map, default: %{}
      add :dominant_colors, {:array, :map}, default: []
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:analyses, [:file_hash])
  end
end
