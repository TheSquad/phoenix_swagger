defmodule PhoenixSwagger do
  @shortdoc "Generate swagger_[action] function for a phoenix controller"
  @moduledoc """
  The PhoenixSwagger module provides swagger_model/2 macro that takes two
  arguments:

    * `action` - name of the controller action (:index, ...)
    * `expr`   - do block that contains swagger definitions

  Example:

      swagger_model :index do
        description "Short description"
        parameter :path, :id, :number, :required, "property id"
        responses 200, "Description", schema
      end

  Where the `schema` is a map that contains swagger response schema
  or a function that returns map.
  """

  @swagger_data_types [:integer, :long, :float, :double, :string,
                       :byte, :binary, :boolean, :date, :dateTime,
                       :password, :file]

  defmacro __using__(_) do
    quote do
      import PhoenixSwagger
    end
  end

  defmacro swagger_model(action, expr) do
    fun_name = ("swagger_" <> to_string(action)) |> String.to_atom
    metadata = unblock(expr)
    description = Keyword.get(metadata, :description)

    IO.puts "Swagger - Processing #{inspect (__CALLER__.module)} #{inspect action}"

    tags = get_tags_module(__CALLER__)
    tags = Keyword.get(metadata, :tags, tags)

    security_enabled = Mix.Project.get.swagger_info |> Enum.into(%{}) |> Map.get(:plug_security)
    security_headers =
    [{:param, [description: "Service's SID",
               in: "header",
               name: :sid,
               required: false,
               type: :string]},
     {:param, [description: "Service's Auth Token",
               in: "header",
               name: :auth,
               required: false,
               type: :string]}]


    parameters = get_parameters(metadata)
    responses = get_responses(metadata)

    parameters = if security_enabled do
      IO.puts "Adding security headers to: #{inspect action}"
      security_headers ++ parameters
    else
      parameters
    end

    IO.inspect parameters

    quote do
      def unquote(fun_name)() do
        {PhoenixSwagger.get_description(__MODULE__, unquote(description)),
         unquote(tags),
         unquote(parameters),
         unquote(responses)}
      end
    end
  end

  def get_description(_, description) when is_list(description) do
    description
  end

  def get_description(module, description) when is_function(description) do
    module.description()
  end

  # Helpers

  defp get_tags_module(caller) do
    caller.module
    |> Module.split
    |> Enum.reverse
    |> hd
    |> String.split("Controller")
    |> Enum.filter(&(String.length(&1) > 0))
  end

  defp get_parameters(parameters) do
    Enum.map(parameters,
      fn(metadata) ->
        case metadata do
          {:parameter, [path, name, type, :required, description]} ->
            {:param, [in: pascalize(path), name: name, type: valid_type?(type), required: true, description: description]}
          {:parameter, [path, name, type, :required]} ->
            {:param, [in: pascalize(path), name: name, type: valid_type?(type), required: true, description: ""]}
          {:parameter, [path, name, type, description]} ->
            {:param, [in: pascalize(path), name: name, type: valid_type?(type), required: false, description: description]}
          {:parameter, [path, name, type]} ->
            {:param, [in: pascalize(path), name: name, type: valid_type?(type), required: false, description: ""]}
          {:parameter, other} ->
            IO.puts "Swagger - Could not match parameter declaration: #{inspect other}"
            []
          _ -> []
        end
      end) |> :lists.flatten
  end

  defp get_responses(responses) do
    Enum.map(responses,
      fn(metadata) ->
        case metadata do
          {:response, [response_code, response_description]} ->
            {:resp, [code: response_code, description: response_description, schema: quote(do: %{})]}
          {:response, [response_code, response_description, response_schema]} ->
            {:resp, [code: response_code, description: response_description, schema: response_schema]}
          {:response, other} ->
            IO.puts "Swagger - Could not match response declaration: #{inspect other}"
            []
          _ -> []
        end
      end) |> :lists.flatten
  end

  defp pascalize(string) when is_binary(string),
  do: Inflex.camelize(string, :lower)

  defp pascalize(other), do: other |> to_string |> pascalize

  defp valid_type?(type) do
    if not (type in @swagger_data_types) do
      raise "Error: write datatype: #{type}"
    else
      type
    end
  end

  defp unblock([do: {:__block__, _, body}]) do
    Enum.map(body, fn({name, _line, params}) -> {name, params} end)
  end
end
