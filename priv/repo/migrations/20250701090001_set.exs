defmodule HSCards.Repo.Migrations.Set do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add(:set, :string)
    end

    create(index(:cards, [:set]))
  end
end
