defmodule HSCards.Repo.Migrations.Initial do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add(:dbfId, :integer, null: false)
      add(:name, :string, null: false)
      add(:full_info, :map, null: false)
    end

    create(unique_index(:cards, [:dbfid]))
  end
end
