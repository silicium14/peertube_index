defmodule PeertubeIndex.VideoStorage do
  @moduledoc false

  @doc """
  Updates an instance with a list of videos.
  This removes existing videos for the given instance and inserts the given videos.
  """
  @callback update_instance!(String.t, [map]) :: :ok

  @doc """
  Search for a video by its name
  Options:
    - nsfw:
      - missing: do not filter on safety, gets both safe and unsafe videos
      - true: only get unsafe for work videos
      - false: only get safe for work videos
  """
  @callback search(String.t, Keyword.t()) :: [map]

  @doc """
  Create a video storage with some videos for testing
  """
  @callback with_videos([map]) :: :ok

  @doc """
  Create an empty video storage for testing
  """
  @callback empty() :: :ok
end

defmodule PeertubeIndex.VideoStorage.Elasticsearch do
  @moduledoc false

  @behaviour PeertubeIndex.VideoStorage

  @index "videos"
  @document_type "_doc"
  def elasticsearch_config, do: Confex.fetch_env!(:peertube_index, :elasticsearch_config)

  @impl true
  def update_instance!(hostname, videos) do
    Elasticsearch.post!(
      elasticsearch_config(),
      "/#{@index}/_delete_by_query",
      %{"query" => %{"term" => %{"account.host" => hostname}}}
    )

    for video <- videos do
      Elasticsearch.post!(elasticsearch_config(), "/#{@index}/#{@document_type}", video)
    end

    :ok
  end

  @impl true
  def search(query, options \\ []) do
    elasticsearch_query = %{
      "from" => "0", "size" => 100,
      "query" => %{
        "bool" => %{
          "must" => [
            %{
              "match" => %{
                "name" => %{
                  "query" => query,
                  "fuzziness" => "AUTO"
                }
              }
            }
          ]
        }
      }
    }
    nsfw = options[:nsfw]
    elasticsearch_query =
    if is_nil(nsfw)  do
      elasticsearch_query
    else
      put_in(elasticsearch_query, ["query", "bool", "filter"], [%{"term" => %{"nsfw" => nsfw}}])
    end

    %{"hits" => %{"hits" => hits}} = Elasticsearch.post!(elasticsearch_config(), "/#{@index}/_search", elasticsearch_query)

    hits
    |> Enum.map(fn hit -> hit["_source"] end)
    |> Enum.to_list()
  end

  defp create_index do
    Elasticsearch.Index.create(
      elasticsearch_config(),
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

  @impl true
  def with_videos(videos) do
    empty()
    videos
    |> Enum.each(fn video -> Elasticsearch.post!(elasticsearch_config(), "/#{@index}/#{@document_type}", video) end)
  end

  @impl true
  def empty do
    _delete_index_ignore_not_exising!()
    create_index()
  end

  defp _delete_index_ignore_not_exising! do
    result = Elasticsearch.delete(elasticsearch_config(), "/#{@index}")
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
