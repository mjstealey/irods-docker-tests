#!/usr/bin/env bash

# Remove icat and resource containers if the already exist
ISICAT=$(docker ps -a | rev | cut -d ' ' -f 1 | rev | grep icat)
ISRESOURCE=$(docker ps -a | rev | cut -d ' ' -f 1 | rev | grep resource)

if [[ "${ISICAT}" == "icat" ]]; then
    echo "REMOVE: icat"
    echo "  - docker stop icat && docker rm -fv icat"
    docker stop icat && docker rm -fv icat
fi
if [[ "${ISRESOURCE}" == "resource" ]]; then
    echo "REMOVE: resource"
    echo "  - docker stop resource && docker rm -fv resource"
    docker stop resource && docker rm -fv resource
fi

# Create icat container from irods v.4.1.8
docker run -d --name icat \
    --env-file icat.env \
    --hostname icat \
    mjstealey/docker-irods-icat:4.1.8

# Wait for icat to stand up
sleep 20s
# Create resource container from irods v.4.1.8
RESOURCEIP=$(docker run --rm mjstealey/docker-irods-resource:4.1.8 /sbin/ip -f inet -4 -o addr | grep eth | cut -d '/' -f 1 | rev | cut -d ' ' -f 1 | rev)
docker exec icat sh -c 'echo "'${RESOURCEIP}' resource" >> /etc/hosts'

docker run -d --name resource \
    --env-file resource.env \
    --hostname resource \
    --link icat:icat \
    mjstealey/docker-irods-resource:4.1.8

# Wait for resource to stand up
sleep 20s

# verify connectivity
# put file into resource owned resource from icat
docker exec -u irods icat iput -R resourceResource irods.config icat-irods.config
# put file into icat owned resource from resource
docker exec -u irods resource iput -R demoResc irods.config resource-irods.config
# use docker-irods-icommnads to verify file placement
docker run --rm --link icat:icat \
    -e IRODS_HOST=icat \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 ils -L

exit 0;