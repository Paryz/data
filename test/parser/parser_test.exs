defmodule Data.ParserTest do
  use ExUnit.Case, async: true
  doctest Data.Parser

  import FE.Maybe, only: [just: 1, nothing: 0]
  import Data.Parser.BuiltIn

  alias Data.Parser
  alias MapSet, as: Set

  describe "predicate/2" do
    test "returns parser that returns the input value if predicate is true" do
      parser = Parser.predicate(fn x -> x > 2 end, Error.domain(:must_be_gt_2))
      assert parser.(3) == {:ok, 3}
    end

    test "returns parser that errors out if predicate is false" do
      error = Error.domain(:must_be_gt_2)
      parser = Parser.predicate(fn x -> x > 2 end, error)
      assert parser.(1) == {:error, error}
    end

    test "if second argument is 1-arity fun, the failed predicate argument is passed to it on error" do
      parser = Parser.predicate(fn x -> x > 2 end, fn x -> {:bad_arg, x} end)
      assert parser.(1) == {:error, {:bad_arg, 1}}
    end
  end

  describe "one_of/2" do
    test "returns parser that returns the input value if it's one of the provided values" do
      parser = Parser.one_of([:a, :b], Error.domain(:must_be_a_or_b))
      assert parser.(:a) == {:ok, :a}
    end

    test "returns parser that returns the default error if run on a value that's not listed" do
      error = Error.domain(:must_be_a_or_b)
      parser = Parser.one_of([:a, :b], error)
      assert parser.(:c) == {:error, error}
    end

    test "returns parser that maps default error on the input if run on a value that's not listed" do
      parser = Parser.one_of([:a, :b], fn x -> "bad value: #{inspect x}" end)
      assert parser.(:c) == {:error, "bad value: :c"}
    end

  end

  describe "maybe/1" do
    test "returns parser that is fmapped onto a just value" do
      parser = Parser.maybe(Parser.BuiltIn.string())
      assert parser.(just("hello")) == {:ok, just("hello")}
    end

    test "returns error if parser fails on just value" do
      error = Error.domain(:not_a_string)
      parser = Parser.maybe(Parser.BuiltIn.string())
      assert parser.(just(0)) == {:error, error}
    end

    test "returns nothing successfully if nothing is passed in" do
      parser = Parser.maybe(Parser.BuiltIn.string())
      assert parser.(nothing()) == {:ok, nothing()}
    end
  end

  describe "list/1" do
    test "successfully parses empty list" do
      assert Parser.list(string()).([]) == {:ok, []}
    end

    test "successfully parses list where all elements parse" do
      assert Parser.list(integer()).([1, 2, 3]) == {:ok, [1, 2, 3]}
    end

    test "returns error when first argument is not a list" do
      assert {:error, error} = Parser.list(integer()).(:abc)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_list
    end

    test "returns first failed parse if some elements don't parse" do
      assert {:error, error} = Parser.list(integer()).([1, "2", 3])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
      assert Error.details(error) == %{failed_element: "2"}
    end
  end

  describe "nonempty_list/1" do
    test "returns error when list is empty" do
      assert {:error, error} = Parser.nonempty_list(string()).([])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :empty_list
    end

    test "returns error when first argument is not a list" do
      assert {:error, error} = Parser.nonempty_list(integer()).(:bada)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_list
    end

    test "successfully parses list when all elements parse" do
      assert Parser.nonempty_list(integer()).([1, 2, 3]) == {:ok, [1, 2, 3]}
    end

    test "returns first failed parse if some elements don't parse" do
      assert {:error, error} = Parser.nonempty_list(string()).(["a", "b", :c])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_string
      assert Error.details(error) == %{failed_element: :c}
    end
  end

  describe "set/1" do
    test "successfully parses empty set" do
      assert Parser.set(string()).(Set.new()) == {:ok, Set.new()}
    end

    test "successfully parses set where all elements parse" do
      assert Parser.set(integer()).(Set.new([1, 2, 3])) == {:ok, Set.new([1, 2, 3])}
    end

    test "returns error when first argument is not a set" do
      assert {:error, error} = Parser.set(integer()).(:abc)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_set
    end

    test "returns first failed parse if some elements don't parse" do
      assert {:error, error} = Parser.set(integer()).(Set.new([1, "2", 3]))
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
      assert Error.details(error) == %{failed_element: "2"}
    end
  end

  describe "kv/1" do

    test "an empty kv run on an empty input returns empty map" do
      {:ok, kv} = Parser.kv([])
      assert kv.(%{}) == {:ok, %{}}
      assert kv.([]) == {:ok, %{}}
    end

    test "an empty kv run on input returns empty map" do
      {:ok, kv} = Parser.kv([])
      assert kv.(%{a: :b, c: :d}) == {:ok, %{}}
      assert kv.(a: :b, c: :d) == {:ok, %{}}
    end

    test "a kv with required field fails if field doesn't exist" do
      {:ok, kv} = Parser.kv([{:count, integer()}])
      assert {:error, error} = kv.(%{})
      assert {:error, ^error} = kv.([])

      assert Error.kind(error) == :domain
      assert Error.reason(error) == :field_not_found_in_input
      assert Error.details(error) == %{field: :count, input: %{}}
    end

    test "a kv with required field fails if the field's parser fails" do
      {:ok, kv} = Parser.kv([{:count, integer()}])
      assert {:error, error} = kv.(%{count: "123"})
      assert {:error, ^error} = kv.(count: "123")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
      assert Error.details(error) == %{field: :count, input: %{count: "123"}}
    end

    test "a kv with required field passes if field's parser passes" do
      {:ok, kv} = Parser.kv([{:count, integer()}])
      assert kv.(%{count: 123}) == {:ok, %{count: 123}}
      assert kv.(count: 123) == {:ok, %{count: 123}}
    end

    test "a kv with optional field passes with nothing if field doesn't exist" do
      {:ok, kv} = Parser.kv([{:height, integer(), optional: true}])
      assert kv.(%{}) == {:ok, %{height: nothing()}}
      assert kv.([]) == {:ok, %{height: nothing()}}
    end

    test "a kv with optional field passes with just if field's parser passes" do
      {:ok, kv} = Parser.kv([{:height, integer(), optional: true}])
      assert kv.(%{height: 123}) == {:ok, %{height: just(123)}}
      assert kv.(height: 123) == {:ok, %{height: just(123)}}
    end

    test "a kv with optional field fails if the field's parser fails" do
      {:ok, kv} = Parser.kv([{:height, integer(), optional: true}])
      assert {:error, error} = kv.(%{height: "123"})
      assert {:error, ^error} = kv.(height: "123")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
      assert Error.details(error) == %{field: :height, input: %{height: "123"}}
    end

    test "a kv with field with default value passes with that value " <>
      "if field doesn't exist" do
      {:ok, kv} = Parser.kv([{:age, integer(), default: 21}])
      assert kv.(%{}) == {:ok, %{age: 21}}
      assert kv.([]) == {:ok, %{age: 21}}
    end

    test "a kv with field with default value passes if field's parser passes" do
      {:ok, kv} = Parser.kv([{:age, integer(), default: 21}])
      assert kv.(%{age: 100}) == {:ok, %{age: 100}}
      assert kv.(age: 100) == {:ok, %{age: 100}}
    end

    test "a kv with field with default value fails if field's parser fails" do
      {:ok, kv} = Parser.kv([{:age, integer(), default: 21}])
      assert {:error, error} = kv.(%{age: "123"})
      assert {:error, ^error} = kv.(age: "123")
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_an_integer
      assert Error.details(error) == %{field: :age, input: %{age: "123"}}
    end

    test "a kv cannot be created with an invalid field spec" do
      assert {:error, error} = Parser.kv([:bad_spec])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_field_spec
      assert Error.details(error) == %{spec: :bad_spec}
    end

    test "a kv with anything else than a list of specs" do
      assert {:error, error} = Parser.kv(:not_a_list_of_specs)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :not_a_list
    end

    test "a kv with a optional and default value field cannot be created" do
      assert {:error, error} = Parser.kv([{:weight, integer(), default: 10, optional: true}])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_field_spec
      assert Error.details(error) == %{spec: {:weight, integer(), default: 10, optional: true}}
    end

  end

  describe "kv/1 bad input" do
    test "a kv run on an atom returns invalid input error" do
      {:ok, kv} = Parser.kv([{:age, integer()}])
      assert {:error, error} = kv.(:xyz)
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_input
      assert Error.details(error) == %{input: :xyz}
    end

    test "a kv run on a non-keyword list returns invalid input error" do
      {:ok, kv} = Parser.kv([{:age, integer()}])
      assert {:error, error} = kv.([:x, :y])
      assert Error.kind(error) == :domain
      assert Error.reason(error) == :invalid_input
      assert Error.details(error) == %{input: [:x, :y]}
    end
  end

end
