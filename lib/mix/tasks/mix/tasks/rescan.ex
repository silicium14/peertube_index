defmodule Mix.Tasks.Rescan do
  use Mix.Task

  @moduledoc """
  Rescans known instances
  """

  @shortdoc """
  Rescans known instances
  """
  def run(_) do
    Application.ensure_all_started :elasticsearch
    PeertubeIndex.rescan
  end
end
