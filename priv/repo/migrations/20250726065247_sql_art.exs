defmodule HSCards.Repo.Migrations.SqlArt do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add(:hs_id, :string)
    end

    create table(:art) do
      # SQlite foreign keys are wonky, so we don't use them
      add(:hs_id, :string, null: false)
      add(:tile, :string)
      add(:full, :string)
    end

    create(unique_index(:art, [:hs_id]))
  end
end
