# rosetta-docker

Docker setup for Rosetta. 

These files are kept separately from Rosetta's [source code](https://github.com/ElrondNetwork/rosetta), so that we can easily reference tagged versions of Rosetta (and Node) in Dockerfiles.

The Docker setup takes the shape of one Docker image (holding both `rosetta` and the `node`), plus a Docker Compose definition to orchestrate the `1 + 1 + 1 = 3` containers: 

 - one _rosetta_ instance in **online mode**
 - one _rosetta_ instance in **offline mode**
 - one _node_, started as observer for a chosen actual shard
  
This `1 + 1 + 1 = 3` setup is usually referred to as an **MultiversX Rosetta Squad**.

Currently, the Rosetta implementation only supports the native currency (EGLD), while custom currencies ([ESDTs](https://docs.elrond.com/developers/esdt-tokens)) will be supported in the near future. At that point, the Docker setup would contain `1 + 1 + 1 + 1 = 4` containers - the additional container being an observer for the _metachain_ (necessary for some pieces of information such as ESDT properties).

## Prerequisites

### Give permissions to the current user

Make sure you read [this article](https://docs.docker.com/engine/install/linux-postinstall/) carefully, before performing the step.

The following command adds the current user to the group "docker":

```
sudo usermod -aG docker $USER
```

After running the command, you may need to log out from the user session and log back in.

## Build the Docker image

```
docker image build --no-cache . -t multiversx-rosetta:latest -f ./Dockerfile
```

## Run the containers

Run on **devnet**:

```
docker compose --file ./docker-compose-devnet.yml --env-file ./devnet.env --project-name multiversx-devnet up --detach
```

Run on **mainnet**:

```
docker compose --file ./docker-compose-mainnet.yml --env-file ./mainnet.env --project-name multiversx-mainnet up --detach
```

## Inspect logs

For devnet:

```
docker logs multiversx-rosetta-observer-devnet --tail 100 --follow
docker logs multiversx-rosetta-online-devnet --tail 100 --follow
docker logs multiversx-rosetta-offline-devnet --tail 100 --follow
```

For mainnet:

```
docker logs multiversx-rosetta-observer-mainnet --tail 100 --follow
docker logs multiversx-rosetta-online-mainnet --tail 100 --follow
docker logs multiversx-rosetta-offline-mainnet --tail 100 --follow
```

## Update the Docker setup

Update the local clone of this repository:

```
git pull origin
```

Stop the running containers (devnet):

```
docker stop multiversx-rosetta-observer-devnet
docker stop multiversx-rosetta-online-devnet
docker stop multiversx-rosetta-offline-devnet

# Or simply:
docker compose --project-name multiversx-devnet down
```

Stop the running containers (mainnet):

```
docker stop multiversx-rosetta-observer-mainnet
docker stop multiversx-rosetta-online-mainnet
docker stop multiversx-rosetta-offline-mainnet

# Or simply:
docker compose --project-name multiversx-mainnet down
```

Re-build the images as described above, then run the containers again.
