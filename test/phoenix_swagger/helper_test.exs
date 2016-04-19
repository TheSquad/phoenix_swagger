defmodule PhoenixSwagger.HelperTest do
  use ExUnit.Case
  import PhoenixSwagger.Helper
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
          required: [:apple, :banana, :peach])
  end

  test "array creation" do
    assert %{type: :array, items: %{type: :string}} =
      schema(:array, items: schema(:string))
  end
end
