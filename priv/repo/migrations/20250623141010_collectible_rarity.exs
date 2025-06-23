defmodule HSCards.Repo.Migrations.CollectibleRarity do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add(:rarity, :string)
      add(:collectible, :boolean, default: false)
    end

    create(index(:cards, [:rarity]))
    create(index(:cards, [:collectible]))
  end
end
