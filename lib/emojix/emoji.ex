defmodule Emojix.Emoji do
  @moduledoc """
  Documentation for Emojix.Emoji.
  """
  defstruct id: nil,
            hexcode: nil,
            description: nil,
            shortcodes: [],
            legacy_shortcodes: [],
            tags: [],
            unicode: nil,
            variations: []

  @type t :: %__MODULE__{
          id: Integer.t(),
          hexcode: String.t(),
          description: String.t(),
          shortcodes: [String.t()],
          legacy_shortcodes: [String.t()],
          tags: [String.t()],
          unicode: String.t(),
          variations: [__MODULE__.t()]
        }
end
