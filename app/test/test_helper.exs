ExUnit.configure exclude: [:integration, :nonregression]
ExUnit.start()
Application.ensure_all_started(:bypass)
