ExUnit.configure exclude: [:integration]
ExUnit.start()
Application.ensure_all_started(:bypass)
Mox.defmock(PeertubeIndex.Storage.Mock, for: PeertubeIndex.Storage)
Mox.defmock(PeertubeIndex.InstanceAPI.Mock, for: PeertubeIndex.InstanceAPI)
Mox.defmock(PeertubeIndex.StatusStorage.Mock, for: PeertubeIndex.StatusStorage)

# TODO: make mocks available at compile time to remove warnings
