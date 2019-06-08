defmodule PeertubeIndex.FrontendHelpers do
  @moduledoc false

  def format_duration(seconds) do
    hours = div(seconds, 3600)
    if hours > 0 do
      formatted_minutes = seconds |> rem(3600) |> div(60) |> to_string |> String.pad_leading(2, "0")
      formatted_seconds = seconds |> rem(3600) |> rem(60) |> to_string |> String.pad_leading(2, "0")
      "#{hours}:#{formatted_minutes}:#{formatted_seconds}"
    else
      minutes = seconds |> div(60)
      formatted_seconds = seconds |> rem(60) |> to_string |> String.pad_leading(2, "0")
      "#{minutes}:#{formatted_seconds}"
    end
  end
end
