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
- When scanning an instance, we stream videos to a file on disk.
Only after we successfully fetched and verified all videos, we insert them in video storage streaming from the disk. 
This avoids storing all the videos for one instance in memory before inserting them in the video storage.
We did this because we ran out of memory when storing all videos in memory before verifying and storing them.
It turns out that the large number of videos some instances have consists mainly of non local videos that we do not need to store.
As long as the number of local videos an instance have fits into memory, we do not need to stream to disk.
Reducing the stream to memory by excluding non local videos is sufficient.
As we discovered this after implementing the streaming to disk, we leave the code as is for the moment.
We took a shortcut by hard coding the file name we use as temporary storage, which prevents running multiple scans concurrently.
- We found that for some instances, some non local videos had an one validation error.
We decided to add and exception that allows this specific validation error for non local videos.
This means we only silent this error and any other validation error will make the scan fail.
We do not want to silent unexpected errors.

**Status database**

- We use PostgreSQL for storing instances status because we need concurrent access without corrupted reads or writes.
We chose to use the ecto library because we will need soon need transactions.

**Search database**

We use Elasticsearch as the search database because :
- we need fast text search 
- we found it was easier to setup and faster to get started with than other databases

**Status monitoring database**
We use PostgreSQL version 10 because it is the highest available version in Grafana PostgreSQL data source setup page.

**Deployment**

We use Docker containers with Docker Compose to deploy the full stack on a single machine, it is enough for the beginning.
