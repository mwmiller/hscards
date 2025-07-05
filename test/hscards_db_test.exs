defmodule HSCardsDBTest do
  use ExUnit.Case, async: true
  doctest HSCards.DB
  alias HSCards.DB

  test "sanity" do
    # Other tests might depend on these values, so we check them up front
    # This will either make it easier to debug or annoy me later
    assert [string_match: :fuzzy, query_mode: :and] = DB.default_options()

    assert [
             :name,
             :dbfId,
             :flavor,
             :artist,
             :mechanic,
             :class,
             :cost,
             :collectible,
             :rarity,
             :text,
             :set,
             :constraint
           ] =
             DB.available_fields()

    assert [:exact, :fuzzy] = DB.available_string_matches()
    assert [:and, :or] = DB.available_query_modes()
  end

  test "match modes" do
    assert {:error, "No match"} = DB.find(%{name: "baster"}, string_match: :exact)

    assert {:ok, %{"name" => "Keymaster Alabaster"}} =
             DB.find(%{name: "baster"}, string_match: :fuzzy)
  end

  test "dbfId types" do
    assert {:error, "No match"} = DB.find(%{dbfId: 1}, string_match: :exact)
    assert {:ok, %{"name" => "Crystalline Oracle"}} = DB.find(%{dbfId: 41173})
  end

  test "name types" do
    assert {:error, "No match"} = DB.find(%{name: "Leeroy"}, string_match: :exact)
    assert {:ambiguous, leeroys} = DB.find(%{name: "Leeroy J"})
    assert length(leeroys) > 8
  end

  test "flavor text" do
    assert {:error, "No match"} = DB.find(%{flavor: "Leeroy"}, string_match: :exact)
    assert {:ok, %{"dbfId" => 104_618}} = DB.find(%{flavor: "Leeroy J"}, string_match: :fuzzy)
    assert {:ambiguous, _} = DB.find(%{flavor: "lee"})
  end

  test "artist search" do
    assert {:error, "No match"} = DB.find(%{artist: "Leeroy"})
    assert {:ambiguous, _} = DB.find(%{artist: "Alex Horley Orlandelli"})

    assert {:ok, %{"dbfId" => 68460}} =
             DB.find(%{artist: "Alex Horley"}, string_match: :exact)
  end

  test "rarity search" do
    assert {:error, "No match"} = DB.find(%{rarity: "NONSENSE"})
    assert {:ambiguous, _} = DB.find(%{rarity: "EPIC"})
    assert {:ambiguous, _} = DB.find(%{rarity: ["epic", "legendary"]})
  end

  test "collectible search" do
    assert {:ambiguous, c} = DB.find(%{collectible: true})
    assert length(c) > 7000
    assert {:ambiguous, u} = DB.find(%{collectible: false})
    assert length(u) > 25000
  end

  test "mechanic search" do
    assert {:error, "No match"} = DB.find(%{mechanic: "NONSENSE"})
    assert {:ambiguous, _} = DB.find(%{mechanic: "Battlecry"})
    assert {:ambiguous, _} = DB.find(%{mechanic: ["Battlecry", "Deathrattle"]})
  end

  test "class search" do
    assert {:error, "No match"} = DB.find(%{class: "NONSENSE"})
    assert {:ambiguous, _} = DB.find(%{class: "Druid"})
    assert {:ambiguous, _} = DB.find(%{class: ["Druid", "Hunter"]})
  end

  test "cost search" do
    assert {:error, "No match"} = DB.find(%{cost: 1000})
    # I hope to never update this test
    assert {:ok, %{"name" => "The Ceaseless Expanse"}} = DB.find(%{cost: 125})
    assert {:ambiguous, _} = DB.find(%{cost: 10})
    assert {:ambiguous, _} = DB.find(%{cost: [1, 2, 3]})
  end

  test "set search" do
    assert {:error, "No match"} = DB.find(%{set: "MRB"})
    assert {:ambiguous, bl} = DB.find(%{set: "WILD_WEST", collectible: true})
    # Should be stable
    assert length(bl) == 183
  end

  test "multiple fields" do
    assert {:error, "No match"} = DB.find(%{name: "baster", rarity: "EPIC"})

    assert {:ok, %{"name" => "Keymaster Alabaster"}} =
             DB.find(%{
               cost: 7,
               mechanic: "TRIGGER_VISUAL",
               rarity: "Legendary",
               flavor: "mastery"
             })

    assert {:ambiguous, out} = DB.find(%{name: ["benedict", "baster"], collectible: true})
    assert length(out) > 4
  end

  test "improper usage" do
    options_msg =
      "Invalid search options. Available string match modes: [:exact, :fuzzy], available query modes: [:and, :or]"

    assert {:error, ^options_msg} = DB.find(%{name: "baster"}, string_match: :invalid)

    assert {:error, ^options_msg} = DB.find(%{name: "baster"}, query_mode: :invalid)

    assert {:error,
            "Invalid search fields. Available fields: [:name, :dbfId, :flavor, :artist, :mechanic, :class, :cost, :collectible, :rarity, :text, :set, :constraint], but got: [:nonsense]"} =
             DB.find(%{nonsense: "baster"})

    assert {:error,
            "Invalid search fields. Available fields: [:name, :dbfId, :flavor, :artist, :mechanic, :class, :cost, :collectible, :rarity, :text, :set, :constraint], but got: [\"nonsense\"]"} =
             DB.find(%{"nonsense" => "baster"})
  end
end
