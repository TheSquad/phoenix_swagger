defmodule PhoenixSwagger.Helper do

  @shortdoc "Helper functions for generating standard swagger schema datatypes."

  @moduledoc """
  The PhoenixSwagger.Helper module provides simple helper functions that
  can be used to simplify generation of Swagger schema definitions.
  """

  @swagger_simple_types [:integer, :long, :float, :double, :string,
                         :byte, :binary, :boolean]

  def schema(type), do: schema(type, [])

  def schema(type, opts) when type in @swagger_simple_types,
  do: gen_simple(type) |> Map.merge(Enum.into(opts, %{}))

  def schema(:object, opts) do
    title      = opts[:title] || "unnamed"
    properties = opts[:properties] || %{}
    required   = opts[:required] || []
    gen_object(properties, required) |> title(title)
  end

  def schema(type, opts), do: raise "Unsupported type and/or options: #{inspect type} & #{inspect opts}"

  def title(%{} = schema, title), do: schema |> Map.put(:title, title)

  def description(%{} = schema, text), do: schema |> Map.put(:description, text)

  def enum(%{type: type} = schema, [_ | _] = values) when type in [:string],
  do: schema |> Map.put(:enum, values)

  # Helpers

  defp gen_simple(type), do: %{type: type}

  defp gen_object(properties, required) do
    %{type: :object,
      properties: properties,
      required: required |> Enum.filter(fn req -> properties |> Map.has_key?(req) end)}
  end
end
