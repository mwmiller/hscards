defmodule HSCardsDBTest do
  use ExUnit.Case
  doctest HSCards.DB
  alias HSCards.DB

  test "sanity" do
    # Other tests might depend on these values, so we check them up front
    # This will either make it easier to debug or annoy me later
    assert [field_match: :fuzzy, query_mode: :and] = DB.default_options()
    assert [:name, :dbfId, :flavor, :artist] = DB.available_fields()
    assert [:exact, :fuzzy] = DB.available_field_matches()
    assert [:and, :or] = DB.available_query_modes()
  end

  test "match modes" do
    assert {:error, "No match"} = DB.find(%{name: "baster"}, field_match: :exact)

    assert {:ok, %{"name" => "Keymaster Alabaster"}} =
             DB.find(%{name: "baster"}, field_match: :fuzzy)
  end

  test "dbfId types" do
    assert {:error, "No match"} = DB.find(%{dbfId: 1}, field_match: :exact)
    assert {:ambiguous, heaps} = DB.find(%{dbfId: 1})
    # This is true today, and it should be monotonically increasing
    assert length(heaps) > 15_000
  end

  test "name types" do
    assert {:error, "No match"} = DB.find(%{name: "Leeroy"}, field_match: :exact)
    assert {:ambiguous, leeroys} = DB.find(%{name: "Leeroy J"})
    assert length(leeroys) > 8
  end

  test "flavor text" do
    assert {:error, "No match"} = DB.find(%{flavor: "Leeroy"}, field_match: :exact)
    assert {:ok, %{"dbfId" => 104_618}} = DB.find(%{flavor: "Leeroy J"}, field_match: :fuzzy)
    assert {:ambiguous, _} = DB.find(%{flavor: "lee"})
  end

  test "artist search" do
    assert {:error, "No match"} = DB.find(%{artist: "Leeroy"})
    assert {:ambiguous, _} = DB.find(%{artist: "Alex Horley Orlandelli"})

    assert {:ok, %{"dbfId" => 68460}} =
             DB.find(%{artist: "Alex Horley"}, field_match: :exact)
  end

  test "improper usage" do
    options_msg =
      "Invalid search options. Available match modes: [:exact, :fuzzy], available query modes: [:and, :or]"

    assert {:error, ^options_msg} = DB.find(%{name: "baster"}, field_match: :invalid)

    assert {:error, ^options_msg} = DB.find(%{name: "baster"}, query_mode: :invalid)

    assert {:error,
            "Invalid search fields. Available fields: [:name, :dbfId, :flavor, :artist], but got: [:nonsense]"} =
             DB.find(%{nonsense: "baster"})

    assert {:error,
            "Invalid search fields. Available fields: [:name, :dbfId, :flavor, :artist], but got: [\"nonsense\"]"} =
             DB.find(%{"nonsense" => "baster"})
  end
end
