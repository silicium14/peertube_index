defmodule PeertubeIndex.Storage.Elasticsearch do
  @moduledoc false

  @behaviour PeertubeIndex.Storage

  @elasticsearch_config Application.fetch_env!(:peertube_index, :elasticsearch_config)
  @index "videos"
  @document_type "_doc"

  @impl true
  def update_instance!(hostname, videos) do
    Elasticsearch.post!(
      @elasticsearch_config,
      "/#{@index}/_delete_by_query",
      %{"query" => %{"term" => %{"account.host" => hostname}}}
    )

    videos
    |> Enum.map(fn video -> Elasticsearch.post!(@elasticsearch_config, "/#{@index}/#{@document_type}", video) end)
    |> Enum.to_list()

    :ok
  end

  @impl true
  def search(name) do
    %{"hits" => %{"hits" => hits}} = Elasticsearch.post!(
      @elasticsearch_config,
      "/#{@index}/_search",
      %{"query" => %{"match" => %{"name" => name}}}
    )

    hits
    |> Enum.map(fn hit -> hit["_source"] end)
    |> Enum.to_list()
  end

  def create_index() do
    Elasticsearch.Index.create(
      @elasticsearch_config,
      @index,
      %{
        "mappings"=> %{
          @document_type=> %{
            "properties"=> %{
              "uuid"=> %{"type"=> "keyword"},
              "name"=> %{"type"=> "text"},
              "nsfw"=> %{"type"=> "boolean"},
              "description"=> %{"type"=> "text"},
              "duration"=> %{"type"=> "long"},
              "views"=> %{"type"=> "long"},
              "likes"=> %{"type"=> "long"},
              "dislikes"=> %{"type"=> "long"},
              "createdAt"=> %{"type"=> "date"},
              "updatedAt"=> %{"type"=> "date"},
              "publishedAt"=> %{"type"=> "date"},
              "account"=> %{
                "properties"=> %{
                  "uuid"=> %{"type"=> "keyword"},
                  "name"=> %{"type"=> "text"},
                  "displayName"=> %{"type"=> "text"},
                  "host"=> %{"type"=> "keyword"}
                }
              },
              "channel"=> %{
                "properties"=> %{
                  "uuid"=> %{"type"=> "keyword"},
                  "name"=> %{"type"=> "text"},
                  "displayName"=> %{"type"=> "text"},
                  "host"=> %{"type"=> "keyword"}
                }
              }
            }
          }
        }
      }
    )
  end

  # Test helper functions below
  # Todo: should we add those functions to behaviour module?

  def _with_videos(videos) do
    _empty()
    videos
    |> Enum.map(fn video -> Elasticsearch.post!(@elasticsearch_config, "/#{@index}/#{@document_type}", video) end)
    |> Enum.to_list()
  end

  def _empty() do
    _delete_index_ignore_not_exising!()
    create_index()
  end

  defp _delete_index_ignore_not_exising!() do
    result = Elasticsearch.delete(@elasticsearch_config, "/#{@index}")
    case result do
      {:ok, _} ->
        :ok
      {:error, %Elasticsearch.Exception{message: "no such index"}} ->
        :ok
      {:error, unexpected_error} ->
        raise unexpected_error
    end
  end

end
