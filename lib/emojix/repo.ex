defmodule Emojix.Repo do
  @moduledoc false

  @external_resource Emojix.DataLoader.dataset_path()
  @all Emojix.DataLoader.dataset_path() |> File.read!() |> Jason.decode!(keys: :atoms)

  Enum.each(@all, fn emoji ->
    Enum.each(emoji.shortcodes, fn shortcode ->
      def find_by_shortcode(unquote(shortcode)) do
        unquote(Macro.escape(emoji))
        |> to_emojix_struct()
      end
    end)
  end)

  def find_by_shortcode(_shortcode), do: nil

  Enum.each(@all, fn emoji ->
    Enum.each(emoji.legacy_shortcodes, fn shortcode ->
      def find_by_legacy_shortcode(unquote(shortcode)) do
        unquote(Macro.escape(emoji))
        |> to_emojix_struct()
      end
    end)
  end)

  def find_by_legacy_shortcode(_shortcode), do: nil

  Enum.each(@all, fn emoji ->
    Enum.each([emoji.hexcode], fn hexcode ->
      def find_by_hexcode(unquote(hexcode)) do
        unquote(Macro.escape(emoji))
        |> to_emojix_struct()
      end
    end)
  end)

  def find_by_hexcode(_hexcode), do: nil

  def all, do: @all

  def search_by_description(description) do
    search_by(:description, description)
  end

  def search_by_tag(tag) do
    search_by(:tags, tag)
  end

  defp to_emojix_struct(nil), do: nil
  defp to_emojix_struct(data) when is_map(data), do: struct(Emojix.Emoji, data)

  defp search_by(field, value) when field in [:tags, :shortcodes, :legacy_shortcodes] do
    @all
    |> Enum.filter(fn emoji ->
      Map.get(emoji, field)
      |> Enum.member?(value)
    end)
    |> Enum.map(&to_emojix_struct/1)
  end

  defp search_by(field, value) do
    @all
    |> Enum.filter(fn emoji ->
      Map.get(emoji, field)
      |> String.contains?(value)
    end)
    |> Enum.map(&to_emojix_struct/1)
  end
end
