# Project decisions
This file contains decisions that may help understanding the project architecture.

**Maintainability**

- We try to decouple use cases code from storage and user interface code (hexagonal architecture).
- We try to use [MaintainableCSS](https://maintainablecss.com/) for structuring CSS

**Instance scanning**

- We do not want to put too much pressure on instances when scanning them so we do not parallelize queries for one instance.
- For the beginning, for the sake of simplicity, we do not retry on scanning error. An instance is marked as failed at 
- Our validation of video documents expects fields that are not in PeerTube OpenAPI spec but that we found were provided by most instances.
We should check monitor video document validation errors per PeerTube instance version to make sure our validation works correctly for newer versions.

**Status database**

- We use JSON files, one per hostname, to store instances status.
This is for simplicity and to avoid having another database dependency.

**Search database**

We use Elasticsearch as the search database because :
- we need fast text search 
- we found it was easier to setup and faster to get started with than other databases

**Deployment**

We use Docker containers with Docker Compose to deploy the full stack on a single machine, it is enough for the beginning.
