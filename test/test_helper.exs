ExUnit.configure exclude: [:integration]
ExUnit.start()
Mox.defmock(PeertubeIndex.Storage.Mock, for: PeertubeIndex.Storage)
Mox.defmock(PeertubeIndex.InstanceAPI.Mock, for: PeertubeIndex.InstanceAPI)

# TODO: make mocks available at compile time to remove warnings
