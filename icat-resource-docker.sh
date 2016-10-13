#!/usr/bin/env bash

# Remove icat and resource containers if the already exist
ISICAT=$(docker ps -a | rev | cut -d ' ' -f 1 | rev | grep icat)
ISRESOURCE=$(docker ps -a | rev | cut -d ' ' -f 1 | rev | grep resource)

if [[ "${ISICAT}" == "icat" ]]; then
    echo "REMOVE: icat"
#    echo "  - rm -rf /home/${USER}/irods/icat"
#    rm -rf /home/${USER}/irods/icat
    echo "  - docker stop icat && docker rm -fv icat"
    docker stop icat && docker rm -fv icat
fi
if [[ "${ISRESOURCE}" == "resource" ]]; then
    echo "REMOVE: resource"
#    echo "  - rm -rf /home/${USER}/irods/resource"
#    rm -rf /home/${USER}/irods/resource
    echo "  - docker stop resource && docker rm -fv resource"
    docker stop resource && docker rm -fv resource
fi

# Create icat container from irods v.4.1.8
#     --volume /home/${USER}/irods/icat:/var/lib/irods/iRODS/server/log \
#mkdir -p /home/${USER}/irods/icat
docker run -d --name icat \
    --env-file icat.env \
    --hostname icat \
    mjstealey/docker-irods-icat:4.1.8 &

# Wait for icat to stand up
sleep 20s
# Create resource container from irods v.4.1.8
RESOURCEIP=$(docker run --rm mjstealey/docker-irods-resource:4.1.8 /sbin/ip -f inet -4 -o addr | grep eth | cut -d '/' -f 1 | rev | cut -d ' ' -f 1 | rev)
docker exec icat sh -c 'echo "'${RESOURCEIP}' resource" >> /etc/hosts'

#     --volume /home/${USER}/irods/resource:/var/lib/irods/iRODS/server/log \
#mkdir -p /home/${USER}/irods/resource
docker run -d --name resource \
    --env-file resource.env \
    --hostname resource \
    --link icat:icat \
    mjstealey/docker-irods-resource:4.1.8

# Wait for resource to stand up
sleep 20s

# verify connectivity
docker exec -u irods icat iput -R resourceResource irods.config icat-irods.config
docker exec -u irods resource iput -R demoResc irods.config resource-irods.config
docker exec -u irods icat ils -L

exit 0;