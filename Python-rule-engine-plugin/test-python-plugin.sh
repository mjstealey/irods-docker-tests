#!/usr/bin/env bash

# Remove provider and consumer containers if the already exist
ISPROVIDER=$(docker ps -a | rev | cut -d ' ' -f 1 | rev | grep provider)

if [[ "${ISPROVIDER}" == "provider" ]]; then
    echo "CLEAN: stop and remove provider container from prior run"
    echo "$ docker stop provider && docker rm -fv provider"
    docker stop provider && docker rm -fv provider
fi

echo "INFO: run Docker container from mjstealey/irods-provider-postgres:latest as provider"
# Create provider container from irods v.4.2.0-preview
docker run -d --name provider \
    --env-file provider.env \
    --hostname provider \
    mjstealey/irods-provider-postgres:latest

# wait for provider to finish standing up
echo "INFO: allow provider container to stand up"
for pc in $(seq 20 -1 1); do
    echo -ne "$pc ...\033[0K\r" && sleep 1;
done

# verify new shared objects
echo "CHECKPOINT: verify shared objects"
echo "$ ls /var/lib/irods/plugins/rule_engines/"
docker exec provider ls /var/lib/irods/plugins/rule_engines/

# verify rule_engine in server_config.json
echo "CHECKPOINT: verify rule_engines stanza"
echo "$ cat /etc/irods/server_config.json | jq '.plugin_configuration.rule_engines'"
docker exec provider sh -c "cat /etc/irods/server_config.json | jq '.plugin_configuration.rule_engines'"
# update training.re and core.py
echo "INFO: add training.re and core.py files to container"
docker cp training.re provider:/etc/irods/training.re
docker cp core.py provider:/etc/irods/core.py
docker exec provider chown -R irods:irods /etc/irods

# install development tools
docker exec provider sudo apt-get update
docker exec provider apt-get -y install git g++ make python-dev help2man unixodbc libfuse-dev libcurl4-gnutls-dev libbz2-dev zlib1g-dev libpam0g-dev libssl-dev libxml2-dev libkrb5-dev unixodbc-dev libjson-perl python-psutil python-jsonschema super python-exif odbc-postgresql

# get github repo
docker exec provider sh -c 'cd $HOME && git clone https://github.com/irods/contrib'

# make and install landing zone example
docker exec provider sudo apt-get -y install irods-externals-* irods-dev
# verify clang++ and cmake
echo "CHECKPOINT: verify clang++ and cmake"
echo "$ which clang++"
docker exec provider sh -c 'export PATH=/opt/irods-externals/cmake3.5.2-0/bin:/opt/irods-externals/clang3.8-0/bin:$PATH && which clang++'
echo "$ which cmake"
docker exec provider sh -c 'export PATH=/opt/irods-externals/cmake3.5.2-0/bin:/opt/irods-externals/clang3.8-0/bin:$PATH && which cmake'
# build and install landing zone example
docker exec provider sh -c 'mkdir $HOME/build_lz'
docker exec provider sh -c 'cd $HOME/build_lz && export PATH=/opt/irods-externals/cmake3.5.2-0/bin:/opt/irods-externals/clang3.8-0/bin:$PATH && cmake $HOME/contrib/microservices/landing_zone_microservices/ && make package && dpkg -i ./irods-landing-zone-example_4.2.0~trusty_amd64.deb'

# add training.re in server_config.json
docker exec provider sh -c "cat /etc/irods/server_config.json | jq '.plugin_configuration.rule_engines[1].plugin_specific_configuration.re_rulebase_set[1] = .plugin_configuration.rule_engines[1].plugin_specific_configuration.re_rulebase_set[0]' > /tmp/temp.json"
docker exec provider sh -c "jq '.plugin_configuration.rule_engines[1].plugin_specific_configuration.re_rulebase_set[0]=\"training\"' /tmp/temp.json > /etc/irods/server_config.json"
docker exec provider chown irods:irods /etc/irods/server_config.json
docker exec provider rm /tmp/temp.json

# output current state of /etc/irods/server_config.json
echo "CHECKPOINT: verify server_config.json"
echo "$ cat /etc/irods/server_config.json"
docker exec provider cat /etc/irods/server_config.json

# add stickers.jpg
echo "TEST: use stickers.jpg example to show python rule in action"
echo "$ wget ftp://ftp.renci.org/pub/irods/training/stickers.jpg"
docker exec -u irods provider wget --quiet ftp://ftp.renci.org/pub/irods/training/stickers.jpg
echo "$ iput stickers.jpg"
docker exec -u irods provider iput stickers.jpg
echo "$ imeta ls -d stickers.jpg"
docker exec -u irods provider imeta ls -d stickers.jpg

exit 0;