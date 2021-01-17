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

**I will stop maintaining PeerTube Index, it will be retired soon.**

Framasoft, the maintainer of PeerTube, now has an official solution for global search on the PeerTube federation: [Sepia Search at https://search.joinpeertube.org/](https://search.joinpeertube.org/).
People can use it instead of PeerTube Index.
It is open source and people can use it to setup their own search engine with their own rules if they want.
It does not automatically discovers new instances as PeerTube index does (by fetching following and followed instances).
