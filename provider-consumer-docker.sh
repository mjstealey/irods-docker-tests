#!/usr/bin/env bash

# Remove icat and resource containers if the already exist
ISPROVIDER=$(docker ps -a | rev | cut -d ' ' -f 1 | rev | grep provider)
ISCONSUMER=$(docker ps -a | rev | cut -d ' ' -f 1 | rev | grep consumer)

if [[ "${ISPROVIDER}" == "provider" ]]; then
    echo "REMOVE: provider"
    echo "  - docker stop provider && docker rm -fv provider"
    docker stop provider && docker rm -fv provider
fi
if [[ "${ISCONSUMER}" == "consumer" ]]; then
    echo "REMOVE: consumer"
    echo "  - docker stop consumer && docker rm -fv consumer"
    docker stop consumer && docker rm -fv consumer
fi

# Create provider container from irods v.4.2.0-preview
docker run -d --name provider \
    --env-file provider.env \
    --hostname provider \
    mjstealey/irods-provider:latest

# Wait for icat to stand up
sleep 20s
# Create consumer container from irods v.4.2.0-preview
CONSUMERIP=$(docker run --rm mjstealey/irods-consumer:latest /sbin/ip -f inet -4 -o addr | grep eth | cut -d '/' -f 1 | rev | cut -d ' ' -f 1 | rev)
docker exec provider sh -c 'echo "'${CONSUMERIP}' consumer" >> /etc/hosts'

docker run -d --name consumer \
    --env-file consumer.env \
    --hostname consumer \
    --link provider:provider \
    mjstealey/irods-consumer:latest

# Wait for resource to stand up
sleep 20s

# verify connectivity
docker exec -u irods provider iput -R consumerResource irods.config provider-irods.config
docker exec -u irods consumer iput -R demoResc irods.config consumer-irods.config
docker exec -u irods provider ils -L

exit 0;