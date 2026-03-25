defmodule NaFoto.Analyses do
  import Ecto.Query
  alias NaFoto.Repo
  alias NaFoto.Analyses.Analysis

  def list_analyses do
    Repo.all(from a in Analysis, order_by: [desc: a.inserted_at])
  end

  def get_analysis!(id), do: Repo.get!(Analysis, id)

  def create_analysis(attrs) do
    %Analysis{}
    |> Analysis.changeset(attrs)
    |> Repo.insert()
  end

  def get_by_hash(hash) do
    Repo.get_by(Analysis, file_hash: hash)
  end
end
