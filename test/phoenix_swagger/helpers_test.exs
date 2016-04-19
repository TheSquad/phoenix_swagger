defmodule PhoenixSwagger.HelpersTest do
  use ExUnit.Case
  import PhoenixSwagger.Helpers
  doctest PhoenixSwagger

  test "string creation" do
    assert %{type: :string} = schema(:string)
  end

  test "string enum creation" do
    assert %{type: :string, enum: ["hi", "hello", "bonjour"]} =
      schema(:string) |> enum(["hi", "hello", "bonjour"])
    assert %{type: :string, enum: ["hi", "hello", "bonjour"]} =
      schema(:string, enum: ["hi", "hello", "bonjour"])
  end

  test "object creation" do
    assert %{type: :object, title: "unnamed", properties: %{}, required: []} = schema(:object)

    assert %{type: :object, title: "unnamed", properties: %{test: %{type: :string}}, required: [:test]} =
      schema(:object, properties: %{test: schema(:string)})
  end

  test "complex object creation" do
    assert %{
      type: :object,
      title: "Fruits",
      properties: %{
        apple: %{type: :string},
        banana: %{type: :string},
        tomato: %{type: :string}},
      required: [:apple, :banana]} =
        schema(:object,
          title: "Fruits",
          properties: %{
            apple: schema(:string),
            banana: schema(:string),
            tomato: schema(:string)},
          required: [:apple, :banana, :peach]) # additional ones are filtered
  end

  test "array creation" do
    assert %{type: :array, items: %{type: :string}} =
      schema(:array, items: schema(:string))
  end
end
