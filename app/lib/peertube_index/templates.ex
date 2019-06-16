defmodule PeertubeIndex.Templates do
  @moduledoc false
  require EEx

  for {template_name, arguments} <- [
    {:about, []},
    {:home, []},
    {:search, [:videos, :query]},
    {:search_bar, [:fixed, :query]},
    {:warning_footer, []},
  ] do
    EEx.function_from_file(:def, template_name, "frontend/#{template_name}.html.eex", arguments)
  end
end
