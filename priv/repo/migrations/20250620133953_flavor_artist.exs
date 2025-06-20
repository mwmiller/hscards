defmodule HSCards.Repo.Migrations.FlavorArtist do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add(:artist, :string, null: false, default: "UNKNOWN")
      add(:flavor, :string, null: false, default: "")
    end

    create(index(:cards, [:artist]))
    create(index(:cards, [:flavor]))
  end
end
