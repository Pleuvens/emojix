defmodule Emojix.App do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Emojix.DataLoader.load_table()
    Supervisor.start_link([], strategy: :one_for_one)
  end
end
