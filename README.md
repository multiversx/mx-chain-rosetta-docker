# rosetta-docker

Docker setup for Rosetta. 

These files are kept separately from Rosetta's [source code](https://github.com/ElrondNetwork/rosetta), so that we can easily reference tagged versions of Rosetta (and Node) in Dockerfiles.

The Docker setup takes the shape of two Docker images (Elrond Rosetta and Elrond Observer), plus a Docker Compose definition to orchestrate the `1 + 1 + 1 = 3` containers: 

 - one Elrond Rosetta instance in **online mode**
 - one Elrond Rosetta instance in **offline mode**
 - one Elrond observer for a chosen regular shard
  
This `1 + 1 + 1 = 3` setup is usually referred to as an **Elrond Rosetta Squad**.

Currently, the Rosetta implementation only supports the native currency (EGLD), while custom currencies ([ESDTs](https://docs.elrond.com/developers/esdt-tokens)) will be supported in the near future. At that point, the Docker setup would contain `1 + 1 + 1 + 1 = 4` containers - the additional container being an Elrond observer for the _metachain_ (necessary for some pieces of information such as ESDT properties).


## Give permissions to the current user

Make sure you read [this article](https://docs.docker.com/engine/install/linux-postinstall/) carefully, before performing the step.

The following command adds the current user to the group "docker":

```
sudo usermod -aG docker $USER
```

After running the command, you may need to log out from the user session and log back in.

## Build the images

Below, we build all the images (including for  _devnet_).

```
docker image build --no-cache . -t elrond-rosetta-observer:latest -f ./Observer.dockerfile
docker image build --no-cache . -t elrond-rosetta:latest -f ./Rosetta.dockerfile
```

### Run rosetta

Run on **devnet**:

```
docker compose --file ./docker-compose-devnet.yml --env-file ./devnet.env --project-name elrond-devnet up --detach
```

Run on **mainnet**:

```
docker compose --file ./docker-compose-mainnet.yml --env-file ./mainnet.env --project-name elrond-mainnet up --detach
```

### Inspect logs of the running containers

Using `docker logs`:

```
# For devnet
docker logs elrond-rosetta-observer-devnet -f
docker logs elrond-rosetta-online-devnet -f
docker logs elrond-rosetta-offline-devnet -f

# For mainnet
docker logs elrond-rosetta-observer-mainnet -f
docker logs elrond-rosetta-online-mainnet -f
docker logs elrond-rosetta-offline-mainnet -f
```

### Update the Docker setup

Update the local clone of this repository:

```
git pull origin
```

Stop the running containers:

```
# For devnet:
docker stop elrond-rosetta-observer-devnet
docker stop elrond-rosetta-online-devnet
docker stop elrond-rosetta-offline-devnet
# Or simply:
docker compose --project-name elrond-devnet down

# For mainnet:
docker stop elrond-rosetta-observer-mainnet
docker stop elrond-rosetta-online-mainnet
docker stop elrond-rosetta-offline-mainnet
# Or simply:
docker compose --project-name elrond-mainnet down
```

Re-build the images as described above, then run the containers again.
