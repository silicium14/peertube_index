directory = "/status_storage"
output_path = "/tmp/statuses.json"
output = File.open!(output_path, [:write])

IO.write(output, "[")

joined =
directory
|> File.ls!()
|> Enum.map(fn file ->
    {:ok, bytes} = :file.read_file("#{directory}/#{file}")
    String.replace(bytes, "\n", "")
end)
|> Enum.join(",")

IO.write(output, joined)
IO.write(output, "]")
File.close(output)
