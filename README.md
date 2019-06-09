# PeerTube Index

PeerTube Index is a centralized search engine for PeerTube videos.
It crawls PeerTube instances, index their videos, and discovers new instances.
It is hosted at [peertube-index.net](https://peertube-index.net).

This project is not affiliated to Framasoft, the maintainer of the [PeerTube](https://github.com/Chocobozzz/PeerTube) software.

## How it works / what it does

- Scans instances if they have not been scanned for more than 24 hours
- Respects robots.txt directives
- Discovers new instances by adding the followed and following instances of a known instance being scanned
- Periodically updates its list of known instances from thefederation.info and instances.joinpeertube.org
- No scanning retry: at the first scanning error (network error, HTTP error, parsing error...) the instance is marked as failed for the next 24h

## State of the project

This is a toy project built with the objectives of
learning the Elixir language and experimenting some coding practices
while building something that may be useful enough to keep me motivated.

I may improve it if it has enough users.

## Contributing

As this a toy project for practice and learning purposes, I do **not** want code contributions for now.
