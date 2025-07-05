defmodule HSCards.Repo.Migrations.Constraint do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add(:constraint, :string, default: "none")
    end

    create(index(:cards, [:constraint]))
  end
end
