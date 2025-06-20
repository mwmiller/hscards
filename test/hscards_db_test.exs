defmodule HSCardsDBTest do
  use ExUnit.Case
  doctest HSCards.DB
  alias HSCards.DB

  test "sanity" do
    # Other tests might depend on these values, so we check them up front
    # This will either make it easier to debug or annoy me later
    assert DB.default_options() == [match: :both, field: :name]
    assert DB.available_fields() == [:name, :dbfId, :flavor, :artist]
    assert DB.available_match_modes() == [:exact, :fuzzy, :both]
  end

  test "match modes" do
    assert {:error, "No match"} = DB.find("baster", match: :exact, field: :name)

    assert {:ok, %{"name" => "Keymaster Alabaster"} = bastermatch} =
             DB.find("baster", match: :fuzzy, field: :name)

    assert {:ok, ^bastermatch} = DB.find("baster", match: :both, field: :name)
  end

  test "dbfID types" do
    assert_raise Ecto.Query.CastError, fn -> DB.find("baster", match: :exact, field: :dbfId) end
    assert {:error, "No match"} = DB.find(1, match: :exact, field: :dbfId)
    assert {:ambiguous, heaps} = DB.find(1, match: :fuzzy, field: :dbfId)
    # This is true today, and it should be monotonically increasing
    assert length(heaps) > 15_000
    assert {:ambiguous, ^heaps} = DB.find(1, match: :both, field: :dbfId)
  end

  test "name types" do
    assert_raise Ecto.Query.CastError, fn -> DB.find(1, match: :exact, field: :name) end
    assert {:error, "No match"} = DB.find("Leeroy", match: :exact, field: :name)
    assert {:ambiguous, leeroys} = DB.find("Leeroy J", match: :fuzzy, field: :name)

    assert {:ambiguous, ^leeroys} =
             DB.find("leeroy jenkins", match: :both, field: :name)
  end

  test "flavor text" do
    assert_raise Ecto.Query.CastError, fn -> DB.find(1, match: :exact, field: :flavor) end
    assert {:error, "No match"} = DB.find("Leeroy", match: :exact, field: :flavor)
    assert {:ok, %{"dbfId" => 104_618}} = DB.find("Leeroy J", match: :fuzzy, field: :flavor)

    assert {:ambiguous, _} =
             DB.find("lee", match: :both, field: :flavor)
  end

  test "artist search" do
    assert_raise Ecto.Query.CastError, fn -> DB.find(1, match: :exact, field: :artist) end
    assert {:error, "No match"} = DB.find("Leeroy", match: :exact, field: :artist)
    assert {:ambiguous, _} = DB.find("Alex Horley Orlandelli", match: :fuzzy, field: :artist)

    assert {:ok, %{"dbfId" => 68460}} =
             DB.find("Alex Horley", match: :both, field: :artist)
  end

  test "improper usage" do
    current_message =
      "Invalid search options. Available match modes: [:exact, :fuzzy, :both], available fields: [:name, :dbfId, :flavor, :artist]"

    assert {:error, ^current_message} = DB.find("baster", match: :invalid, field: :name)

    assert {:error, ^current_message} = DB.find("baster", match: :exact, field: :invalid)
  end
end
