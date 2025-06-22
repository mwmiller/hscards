defmodule HSCards.Repo.Migrations.ClassyMechanicsCost do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add(:mechanic, :string, default: "")
      add(:class, :string, default: "")
      add(:cost, :integer)
    end

    create(index(:cards, [:class]))
    create(index(:cards, [:mechanic]))
    create(index(:cards, [:cost]))
  end
end
