defmodule Emojix.DataLoader do
  @moduledoc false

  require Logger

  require IEx
  alias Mint.HTTP

  @emoji_version "15.3.1"
  @download_host "cdn.jsdelivr.net"
  @download_path "/npm/emojibase-data@#{@emoji_version}/en/compact.json"
  @download_shortcodes "/npm/emojibase-data@#{@emoji_version}/en/shortcodes/iamcal.json"
  @download_legacy_shortcodes "/npm/emojibase-data@#{@emoji_version}/en/shortcodes/emojibase-legacy.json"
  @dataset_file_name "dataset_#{@emoji_version}.json"

  def dataset_path do
    Path.join(:code.priv_dir(:emojix), @dataset_file_name)
  end

  def load_table do
    if not dataset_exists?() do
      download_and_populate()
    end
  end

  defp download_and_populate do
    Logger.debug("Downloading emoji dataset")
    json = Jason.decode!(download_file(@download_path), keys: :atoms)
    shortcodes = Jason.decode!(download_file(@download_shortcodes), keys: :strings)

    legacy_shortcodes =
      Jason.decode!(download_file(@download_legacy_shortcodes), keys: :strings)

    create_dataset(json, shortcodes, legacy_shortcodes)
  end

  defp download_file(path) when is_binary(path) do
    {:ok, conn} = HTTP.connect(:https, @download_host, 443)

    {:ok, conn, request_ref} =
      HTTP.request(conn, "GET", path, [{"content-type", "application/json"}], "")

    {:ok, conn, body} = stream_request(conn, request_ref)

    Mint.HTTP.close(conn)
    body
  end

  defp create_dataset(json, shortcodes, legacy_shortcodes) when is_map(json) and is_map(shortcodes) and is_map(legacy_shortcodes) do
    Logger.debug("Building emoji dataset")

    emoji_list =
      parse_json(json, shortcodes)
      |> Enum.reduce([], fn e, acc ->
        e.variations ++ [e | acc]
      end)

    legacy_emoji_list =
      parse_json(json, legacy_shortcodes, true)
      |> Enum.reduce([], fn e, acc ->
        e.variations ++ [e | acc]
      end)

    Logger.debug("Populating dataset with #{Enum.count(emoji_list)} emojis")

    dataset = Enum.map(1..Enum.count(emoji_list), fn id ->
      %Emojix.Emoji{
        Enum.at(emoji_list, id - 1) |
        legacy_shortcodes: Map.get(Enum.at(legacy_emoji_list, id - 1), :legacy_shortcodes, []),
        variations: []
      }
      |> Map.from_struct()
    end)
    |> Jason.encode!()

    File.write(dataset_path(), dataset)
  end

  defp parse_json(json, json_shortcodes, legacy? \\ false) when is_map(json) and is_map(json_shortcodes) do
    json
    |> Stream.filter(&Map.has_key?(&1, :order))
    |> Enum.reduce([], fn emoji, list ->
      [build_emoji_struct(emoji, json_shortcodes, legacy?) | list]
    end)
  end

  defp build_emoji_struct(emoji, json_shortcodes, legacy?) when is_map(emoji) and is_map(json_shortcodes) do
    shortcodes = Map.get(json_shortcodes, emoji.hexcode, [])

    if legacy? do
      %Emojix.Emoji{
        id: emoji.order,
        hexcode: emoji.hexcode,
        description: emoji.label,
        legacy_shortcodes: List.wrap(shortcodes),
        unicode: emoji.unicode,
        tags: Map.get(emoji, :tags, []),
        variations:
          Map.get(emoji, :skins, [])
          |> Enum.map(&build_emoji_struct(&1, json_shortcodes, legacy?))
      }
    else
      %Emojix.Emoji{
        id: emoji.order,
        hexcode: emoji.hexcode,
        description: emoji.label,
        shortcodes: List.wrap(shortcodes),
        unicode: emoji.unicode,
        tags: Map.get(emoji, :tags, []),
        variations:
          Map.get(emoji, :skins, [])
          |> Enum.map(&build_emoji_struct(&1, json_shortcodes, legacy?))
      }
    end
  end

  defp dataset_exists? do
    File.exists?(dataset_path())
  end

  defp stream_request(conn, request_ref, body \\ []) do
    {conn, body, status} =
      receive do
        message ->
          {:ok, conn, responses} = HTTP.stream(conn, message)

          {body, status} =
            Enum.reduce(responses, {body, :incomplete}, fn resp, {body, _status} ->
              case resp do
                {:data, ^request_ref, data} ->
                  {body ++ [data], :incomplete}

                {:done, ^request_ref} ->
                  {body, :done}

                _ ->
                  {body, :incomplete}
              end
            end)

          {conn, body, status}
      end

    if status == :done do
      {:ok, conn, body}
    else
      stream_request(conn, request_ref, body)
    end
  end
end
