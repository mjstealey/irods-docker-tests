#!/usr/bin/env bash

# iRODS variables

# Zone 1 User
ZONE1_USER=zone1_user
ZONE1_PASS=zone1_pass
ZONE2_PRIV=own

# Zone 2 User
ZONE2_USER=zone2_user
ZONE2_PASS=zone2_pass
ZONE1_PRIV=own

# Shared zone key information
FED_ZONE_KEY=zone1_and_zone2_ZONE_KEY
FED_NEGOTIATION_KEY=zone1_and_zone2__NEGOTIATION_KEY

# Stand up zone1 and zone2 irods servers
# Remove icat1 and icat2 containers if the already exist
ISICAT1=$(docker ps -a | rev | cut -d ' ' -f 1 | rev | grep icat1)
ISICAT2=$(docker ps -a | rev | cut -d ' ' -f 1 | rev | grep icat2)

if [[ "${ISICAT1}" == "icat1" ]]; then
    echo "REMOVE: icat1"
    echo "  - docker stop icat1 && docker rm -fv icat1"
    docker stop icat1 && docker rm -fv icat1
fi
if [[ "${ISICAT2}" == "icat2" ]]; then
    echo "REMOVE: icat2"
    echo "  - docker stop icat2 && docker rm -fv icat2"
    docker stop icat2 && docker rm -fv icat2
fi

# Create icat1 container from irods v.4.1.8
docker run -d --name icat1 \
    -e IRODS_ZONE_NAME=tempZone1 \
    -e IRODS_DATABASE_SERVER_HOSTNAME=icat1 \
    --hostname icat1 \
    mjstealey/docker-irods-icat:4.1.8

# Create icat2 container from irods v.4.1.8
docker run -d --name icat2 \
    -e IRODS_ZONE_NAME=tempZone2 \
    -e IRODS_DATABASE_SERVER_HOSTNAME=icat2 \
    --hostname icat2 \
    mjstealey/docker-irods-icat:4.1.8

# wait for icat1 and icat2 to finish standing up
echo "INFO: allow icat1 and icat2 to stand up and be configured"
for pc in $(seq 20 -1 1); do
    echo -ne "$pc ...\033[0K\r" && sleep 1;
done

# Make icat1 and icat2 aware of each other via /etc/hosts
echo "INFO: update /etc/hosts"
ICAT1IP=$(docker exec icat1 /sbin/ip -f inet -4 -o addr | grep eth | cut -d '/' -f 1 | rev | cut -d ' ' -f 1 | rev)
ICAT2IP=$(docker exec icat2 /sbin/ip -f inet -4 -o addr | grep eth | cut -d '/' -f 1 | rev | cut -d ' ' -f 1 | rev)
echo "[zone1]$ echo \"'${ICAT2IP}' resource\" >> /etc/hosts"
docker exec icat1 sh -c 'echo "'${ICAT2IP}' resource" >> /etc/hosts'
echo "[zone2]$ echo \"'${ICAT1IP}' resource\" >> /etc/hosts"
docker exec icat2 sh -c 'echo "'${ICAT1IP}' resource" >> /etc/hosts'

echo "INFO: adding rodsuser to each zone"
# Add users to each zone
echo "[zone1]$ iadmin mkuser ${ZONE1_USER} rodsuser"
docker run --rm \
    -e IRODS_HOST=${ICAT1IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone1 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    iadmin mkuser ${ZONE1_USER} rodsuser
echo "[zone1]$ iadmin moduser ${ZONE1_USER} password ${ZONE1_PASS}"
docker run --rm \
    -e IRODS_HOST=${ICAT1IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone1 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    iadmin moduser ${ZONE1_USER} password ${ZONE1_PASS}
echo "[zone2]$ iadmin mkuser ${ZONE2_USER} rodsuser"
docker run --rm \
    -e IRODS_HOST=${ICAT2IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone2 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    iadmin mkuser ${ZONE2_USER} rodsuser
echo "[zone2]$ iadmin moduser ${ZONE2_USER} password ${ZONE1_PASS}"
docker run --rm \
    -e IRODS_HOST=${ICAT2IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone2 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    iadmin moduser ${ZONE2_USER} password ${ZONE2_PASS}

# Add zone2 information to zone1
echo "[zone1]$ iadmin mkzone tempZone2 remote ${ICAT2IP}:1247"
docker run --rm \
    -e IRODS_HOST=${ICAT1IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone1 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    iadmin mkzone tempZone2 remote ${ICAT2IP}:1247
echo "[zone1]$ iadmin mkuser ${ZONE2_USER}#tempZone2 rodsuser"
docker run --rm \
    -e IRODS_HOST=${ICAT1IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone1 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    iadmin mkuser ${ZONE2_USER}\#tempZone2 rodsuser
echo "[zone1]$ ichmod -r -M ${ZONE1_PRIV} ${ZONE2_USER}#tempZone2 /tempZone1/home/${ZONE1_USER}"
docker run --rm \
    -e IRODS_HOST=${ICAT1IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone1 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    ichmod -r -M ${ZONE1_PRIV} ${ZONE2_USER}\#tempZone2 /tempZone1/home/${ZONE1_USER}
echo "[zone1]$ ichmod -r -M inherit /tempZone1/home/${ZONE1_USER}"
docker run --rm \
    -e IRODS_HOST=${ICAT1IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone1 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    ichmod -r -M inherit /tempZone1/home/${ZONE1_USER}

# Add zone1 information to zone2
echo "[zone2]$ iadmin mkzone tempZone1 remote ${ICAT1IP}:1247"
docker run --rm \
    -e IRODS_HOST=${ICAT2IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone2 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    iadmin mkzone tempZone1 remote ${ICAT1IP}:1247
echo "[zone2]$ iadmin mkuser ${ZONE1_USER}#tempZone1 rodsuser"
docker run --rm \
    -e IRODS_HOST=${ICAT2IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone2 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    iadmin mkuser ${ZONE1_USER}\#tempZone1 rodsuser
echo "[zone2]$ ichmod -r -M ${ZONE2_PRIV} ${ZONE1_USER}#tempZone1 /tempZone2/home/${ZONE2_USER}"
docker run --rm \
    -e IRODS_HOST=${ICAT2IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone2 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    ichmod -r -M ${ZONE2_PRIV} ${ZONE1_USER}\#tempZone1 /tempZone2/home/${ZONE2_USER}
echo "[zone2]$ ichmod -r -M inherit /tempZone2/home/${ZONE2_USER}"
docker run --rm \
    -e IRODS_HOST=${ICAT2IP} \
    -e IRODS_PORT=1247 \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone2 \
    -e IRODS_PASSWORD=rods \
    mjstealey/docker-irods-icommands:4.1.8 \
    ichmod -r -M inherit /tempZone2/home/${ZONE2_USER}

exit 0;