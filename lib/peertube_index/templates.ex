defmodule PeertubeIndex.Templates do
  @moduledoc false
  require EEx

  for {template_name, arguments} <- [
    {:about, []},
    {:home, []},
    {:search, [:videos, :query]},
    {:search_bar, [:query]},
    {:warning_footer, []},
    {:retirement_message, []},
  ] do
    EEx.function_from_file(:def, template_name, "frontend/#{template_name}.html.eex", arguments)
  end
end
