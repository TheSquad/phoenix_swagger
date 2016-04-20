defmodule PhoenixSwagger.Helpers do

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
    required   = opts[:required] || :all
    gen_object(properties, required) |> title(title)
  end

  def schema(:array, opts), do: (opts[:items] || []) |> gen_array

  def schema(type, opts), do: raise "Unsupported type and/or options: #{inspect type} & #{inspect opts}"

  # External helpers

  def title(%{} = schema, title), do: schema |> Map.put(:title, title)

  def description(%{} = schema, text), do: schema |> Map.put(:description, text)

  def enum(%{type: type} = schema, [_ | _] = values) when type in [:string],
  do: schema |> Map.put(:enum, values)

  # Internal helpers

  defp gen_simple(type), do: %{type: type}

  defp gen_object(%{} = properties, required) do
    if (properties |> Enum.empty?), do: %{type: :object},
                                  else: gen_object_internal(properties, required)
  end

  defp gen_object_internal(properties, :all),    do: gen_object_internal(properties, properties |> Map.keys)
  defp gen_object_internal(properties, :none),   do: gen_object_internal(properties, [])
  defp gen_object_internal(properties, required) do
    %{type: :object,
      properties: properties,
      required: required |> Enum.filter(fn req -> properties |> Map.has_key?(req) end)}
  end

  defp gen_array(%{} = items_schema) do
    %{type: :array, items: items_schema}
  end
end
