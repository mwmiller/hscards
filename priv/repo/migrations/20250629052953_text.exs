defmodule HSCards.Repo.Migrations.Text do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add(:text, :string, default: "")
    end

    create(index(:cards, [:text]))
  end
end
