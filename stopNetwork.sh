#!/bin/bash

docker compose -f docker/docker-compose-4org.yaml down
sleep 2

docker compose -f docker/docker-compose-ca.yaml down
sleep 2

docker rm -f $(docker ps -a | awk '($2 ~ /dev-peer.*/) {print $1}')

docker volume rm $(docker volume ls -q)

rm -rf channel-artifacts/
rm basic.tar.gz
rm basic_2.tar.gz
rm -rf organizations/

docker ps -a

#docker rm $(docker container ls -q) --force

yes | docker container prune

yes | docker system prune

yes | docker volume prune

yes | docker network prune