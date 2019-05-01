#!/usr/bin/env sh

PAUSE_DURATION=300

while [ 1 ]; do
    echo "$(date) Seeding from instances.joinpeertube.org"
    { time mix seed_from_instances_joinpeertube_org; }
    echo "$(date) Seeding from the-federation.info"
    { time mix seed_from_the_federation_info; }
    echo "$(date) Waiting ${PAUSE_DURATION} seconds"
    sleep ${PAUSE_DURATION}
done
