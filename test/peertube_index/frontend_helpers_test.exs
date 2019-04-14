defmodule FrontendHelpersTest do
  use ExUnit.Case, async: true

  alias PeertubeIndex.FrontendHelpers

  @moduletag :capture_log

  doctest FrontendHelpers

  for {seconds, expected_output} <- [
    {10, "0:10"},
    {70, "1:10"},
    {3600 * 2 + 60 * 30 + 11, "2:30:11"},
    {60, "1:00"},
    {3600, "1:00:00"},
    {3600 + 1, "1:00:01"},
    {3600 * 25, "25:00:00"}
  ] do
    test "format_duration converts #{seconds} to #{expected_output}" do
      assert FrontendHelpers.format_duration(unquote(seconds)) == unquote(expected_output)
    end
  end
end
