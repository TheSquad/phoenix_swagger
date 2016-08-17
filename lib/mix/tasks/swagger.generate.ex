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

require Logger

  def run(output_file) do
    config =
      if function_exported?(Mix.Project.get, :swagger_config, 0),
      do: Mix.Project.get.swagger_config,
      else: []

      app_name = Mix.Project.get.project[:app]
      app_mod = Mix.Project.get.application[:mod] |> elem(0)
      app_pipelines = config[:router_pipelines] || [:api]

      ebin = @app_path <> "_build/" <> (Mix.env |> to_string) <> "/lib/" <> (app_name |> to_string) <> "/ebin"
      Code.append_path(ebin)

      IO.puts "Sorting APIs..."

      sorted_paths = %{}
      |> merge_paths(Module.concat(app_mod, Router), app_mod, app_pipelines)
      |> get_in([:paths])
      |> Enum.to_list
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
      |> Enum.sort

      swagger_json = %{swagger: "2.0"}
      |> merge_info()
      |> merge_host(app_name, app_mod, config)
      |> Map.put_new(:paths, sorted_paths)

      swagger_json = swagger_json
      |> JSON.encode
      |> elem(1)

      File.write(output_file, swagger_json)
      Code.delete_path(ebin)
      IO.puts "Done."
  end

  # Helpers

  defp merge_info(swagger_map) do
    default_info = %{title: @default_title, version: @default_version}

    info =
    if function_exported?(Mix.Project.get, :swagger_info, 0) do
      default_info
      |> Map.merge(Enum.into(Mix.Project.get.swagger_info, %{}))
    else
      default_info
    end
    %{info: info} |> Map.merge(swagger_map)
  end

  defp merge_host(swagger_map, app_name, app_mod, config) do
    endpoint_config = Application.get_env(app_name, Module.concat([app_mod, :Endpoint]))

    host = config[:host] || endpoint_config[:url][:host] || "localhost"
    port = config[:port] || endpoint_config[:url][:port] || endpoint_config[:http][:port] || 4000
    port = case port do
             val when is_binary(val) or is_number(val) -> val
             _                                         -> @default_port
           end

    host_map = %{host: "#{host}:#{port}"}

    case endpoint_config[:https] do
      nil -> host_map
      _   -> host_map |> Map.put(:schemes, ["https", "http"])
    end
    |> Map.merge(swagger_map)
  end

  defp merge_paths(swagger_map, router_mod, app_mod, app_pipelines) do
    api_routes =
      get_api_routes(router_mod, app_pipelines)
      |> Enum.map(fn route -> {route, get_api(app_mod, route)} end)

    paths =
      Enum.reduce(api_routes, %{}, fn ({api_route, {controller, swagger_fun}}, acc) ->
        if not function_exported?(controller, swagger_fun, 0) do
          acc
        else
          {[description], tags, parameters, responses} = apply(controller, swagger_fun, [])
          new_path = format_path(api_route.path)
          new_method =
            %{api_route.verb => %{
             description: description,
             tags: tags,
             parameters: get_parameters(parameters),
             responses: get_responses(responses)}}

          case acc |> Map.get(new_path) do
            nil              -> acc |> Map.put(new_path, new_method)
            existing_methods ->
              acc |> Map.put(new_path, existing_methods |> Map.merge(new_method))
          end
        end
      end)

    case swagger_map |> Map.get(:paths) do
      nil            -> swagger_map |> Map.put(:paths, paths)
      existing_paths ->
        swagger_map |> Map.put(:paths, existing_paths |> Map.merge(paths))
    end
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

  require Logger

  defp get_api_routes(router_mod, app_pipelines) do
    pp = Enum.filter(router_mod.__routes__,
      fn(route_path) ->
        route_path.pipe_through |> Enum.all?(fn x -> x in app_pipelines end)
      end)
      |> Enum.sort_by(&(&1.helper))
    pp
  end

  defp get_parameters(parameters) do
    for {:param, params_list} <- parameters, do: Enum.into(params_list, %{})
  end

  defp get_responses(responses) do
    for {:resp, [code: code, description: desc, schema: schema]} <- responses, into: %{} do
      response_map = %{description: desc}
      response_map =
      if not (schema |> Enum.empty?), do: response_map |> Map.put(:schema, schema),
      else: response_map
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
