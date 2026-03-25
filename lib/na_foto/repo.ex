defmodule NaFoto.Repo do
  use Ecto.Repo,
    otp_app: :na_foto,
    adapter: Ecto.Adapters.SQLite3
end
