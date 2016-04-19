defmodule Mix.Tasks.Phoenix.Swagger.Generate do
  use Mix.Task

  @shortdoc "Generates swagger.json file based on phoenix router"

  @moduledoc """
  Generates swagger.json file based on phoenix router and controllers.

  Usage:

      mix phoenix.swagger.generate

      mix phoenix.swagger.generate ../swagger.json
  """

  @default_port 4000
  @default_title "<enter your title>"
  @default_version "0.0.1"

  @app_path Enum.at(Mix.Project.load_paths, 0) |> String.split("_build") |> Enum.at(0)
  @swagger_file_name "swagger.js"
  @swagger_file_path @app_path <> @swagger_file_name

  @doc false
  def run([]), do: run(@swagger_file_path)

  def run([output_file]), do: run(output_file)

  def run(opts) when is_list(opts) do
    IO.puts """
    Usage: mix phoenix.swagger.generate [FILE]

    With no FILE, default swagger file - #{@swagger_file_path}.
    """
  end

  def run(output_file) do
    app_name = Mix.Project.get.project[:app]
    app_mod = Mix.Project.get.application[:mod] |> elem(0)

    # append path with the given application
    ebin = @app_path <> "_build/" <> (Mix.env |> to_string) <> "/lib/" <> (app_name |> to_string) <> "/ebin"
    Code.append_path(ebin)

    swagger_json =
      %{swagger: "2.0"}
      |> merge_info()
      |> merge_host(app_name, app_mod)
      |> merge_paths(Module.concat(app_mod, Router), app_mod)
      |> Poison.encode!

    File.write(output_file, swagger_json)
    Code.delete_path(ebin)
    IO.puts "Done."
  end

  # Helpers

  defp merge_info(swagger_map) do
    default_info = %{title: @default_title, version: @default_version}

    if function_exported?(Mix.Project.get, :swagger_info, 0) do
      default_info
      |> Map.merge(Enum.into(Mix.Project.get.swagger_info, %{}))
    else
      default_info
    end
    |> Map.merge(swagger_map)
  end

  defp merge_paths(swagger_map, router_mod, app_mod) do
    api_routes =
      get_api_routes(router_mod)
      |> Enum.map(fn route -> {route, get_api(app_mod, route)} end)

    paths =
      for {api_route, {controller, swagger_fun}} <- api_routes,
          function_exported?(controller, swagger_fun, 0),
          into: %{} do

        {[description], tags, parameters, responses} = apply(controller, swagger_fun, [])

        {format_path(api_route.path),
          %{api_route.verb => %{
            description: description,
            tags: tags,
            parameters: get_parameters(parameters),
            responses: get_responses(responses)}}}
      end
    %{paths: paths} |> Map.merge(swagger_map)
  end

  defp merge_host(swagger_map, app_name, app_mod) do
    endpoint_config = Application.get_env(app_name,Module.concat([app_mod, :Endpoint]))
    [{:host, host}] = endpoint_config[:url] || [{:host, "localhost"}]
    [{:port, port}] = endpoint_config[:http] || [{:port, @default_port}]

    host_map = %{host: "#{host}:#{port}"}

    case endpoint_config[:https] do
      nil -> host_map
      _   -> host_map |> Map.put(:schemes, ["https", "http"])
    end
    |> Map.merge(swagger_map)
  end


  defp format_path(path) do
    case String.split(path, ":") do
      [_] -> path
      path_list ->
        List.foldl(path_list, "", fn(p, acc) ->
          if not String.starts_with?(p, "/") do
            [parameter | rest] = String.split(p, "/")
            parameter = acc <> "{" <> parameter <> "}"
            case rest do
              [] -> parameter
              _ ->  parameter <> "/" <> Enum.join(rest, "/")
            end
          else
            acc <> p
          end
        end)
    end
  end

  defp get_api_routes(router_mod) do
    Enum.filter(router_mod.__routes__,
      fn(route_path) ->
        route_path.pipe_through == [:api]
      end)
  end

  defp get_parameters(parameters) do
    for {:param, params_list} <- parameters, do: Enum.into(params_list, %{})
  end

  defp get_responses(responses) do
    for {:resp, [code: code, description: desc, schema: schema]} <- responses, into: %{} do
      response_map = %{description: desc}
      response_map = if not (schema |> Enum.empty?), do: response_map |> Map.put(:schema, schema)
      {code |> to_string, response_map}
    end
  end

  defp get_api(_app_mod, route_map) do
    controller = Module.concat([:Elixir | Module.split(route_map.plug)])
    swagger_fun = ("swagger_" <> to_string(route_map.opts)) |> String.to_atom
    if Code.ensure_loaded?(controller) == false do
      raise "Error: #{controller} module didn't load."
    else
      {controller, swagger_fun}
    end
  end
end
