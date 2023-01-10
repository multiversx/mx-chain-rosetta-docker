FROM golang:1.17.6 as builder

ARG ROSETTA_DEVNET_TAG=v0.3.5
ARG ROSETTA_MAINNET_TAG=v0.3.5
ARG ROSETTA_DOCKER_SCRIPTS_TAG=v0.2.3

# Corresponds to mx-chain-go v1.3.50-hf01
ARG CONFIG_DEVNET_TAG=D1.3.50.0-hf01
# Corresponds to mx-chain-go v1.3.50
ARG CONFIG_MAINNET_TAG=v1.3.50.0

# Clone repositories
WORKDIR /repos
RUN git clone https://github.com/multiversx/mx-chain-rosetta-docker-scripts.git --branch=${ROSETTA_DOCKER_SCRIPTS_TAG} --single-branch --depth=1
RUN git clone https://github.com/multiversx/mx-chain-devnet-config --branch=${CONFIG_DEVNET_TAG} --single-branch --depth=1
RUN git clone https://github.com/multiversx/mx-chain-mainnet-config --branch=${CONFIG_MAINNET_TAG} --single-branch --depth=1

WORKDIR /go
RUN git clone https://github.com/multiversx/mx-chain-go --branch=$(cat /repos/mx-chain-devnet-config/binaryVersion | sed 's/tags\///') --single-branch mx-chain-go-devnet
RUN git clone https://github.com/multiversx/mx-chain-go --branch=$(cat /repos/mx-chain-mainnet-config/binaryVersion | sed 's/tags\///') --single-branch mx-chain-go-mainnet
RUN git clone https://github.com/multiversx/mx-chain-rosetta --branch=${ROSETTA_DEVNET_TAG} --depth=1 rosetta-devnet
RUN git clone https://github.com/multiversx/mx-chain-rosetta --branch=${ROSETTA_MAINNET_TAG} --depth=1 rosetta-mainnet

# Build rosetta (devnet)
WORKDIR /go/rosetta-devnet/cmd/rosetta
RUN go build

# Build rosetta (mainnet)
WORKDIR /go/rosetta-mainnet/cmd/rosetta
RUN go build

# Build node (devnet)
WORKDIR /go/mx-chain-go-devnet/cmd/node
RUN go build -i -v -ldflags="-X main.appVersion=$(git describe --tags --long --dirty --always)"
RUN cp /go/pkg/mod/github.com/!elrond!network/arwen-wasm-vm@$(cat /go/mx-chain-go-devnet/go.mod | grep arwen-wasm-vm | sed 's/.* //' | tail -n 1)/wasmer/libwasmer_linux_amd64.so /go/mx-chain-go-devnet/cmd/node/libwasmer_linux_amd64.so

# Build node (mainnet)
WORKDIR /go/mx-chain-go-mainnet/cmd/node
RUN go build -i -v -ldflags="-X main.appVersion=$(git describe --tags --long --dirty --always)"
RUN cp /go/pkg/mod/github.com/!elrond!network/arwen-wasm-vm@$(cat /go/mx-chain-go-mainnet/go.mod | grep arwen-wasm-vm | sed 's/.* //' | tail -n 1)/wasmer/libwasmer_linux_amd64.so /go/mx-chain-go-mainnet/cmd/node/libwasmer_linux_amd64.so

# Build key generator
WORKDIR /go/mx-chain-go-mainnet/cmd/keygenerator
RUN go build .

# Adjust configuration files
RUN apt-get update && apt-get -y install python3-pip && pip3 install toml
RUN python3 /repos/mx-chain-rosetta-docker-scripts/adjust_config.py --mode=main --file=/repos/mx-chain-devnet-config/config.toml --api-simultaneous-requests=16384 && \
    python3 /repos/mx-chain-rosetta-docker-scripts/adjust_config.py --mode=prefs --file=/repos/mx-chain-devnet-config/prefs.toml && \
    python3 /repos/mx-chain-rosetta-docker-scripts/adjust_config.py --mode=main --file=/repos/mx-chain-mainnet-config/config.toml --api-simultaneous-requests=16384 && \
    python3 /repos/mx-chain-rosetta-docker-scripts/adjust_config.py --mode=prefs --file=/repos/mx-chain-mainnet-config/prefs.toml

# ===== SECOND STAGE ======
FROM ubuntu:20.04

# "wget" is required by "entrypoint.sh" (download steps)
RUN apt-get update && apt-get install -y wget

COPY --from=builder "/go/rosetta-devnet/cmd/rosetta/rosetta" "/app/devnet/"
COPY --from=builder "/go/rosetta-mainnet/cmd/rosetta/rosetta" "/app/mainnet/"
COPY --from=builder "/go/mx-chain-go-devnet/cmd/node/node" "/app/devnet/"
COPY --from=builder "/go/mx-chain-go-mainnet/cmd/node/node" "/app/mainnet/"
COPY --from=builder "/go/mx-chain-go-devnet/cmd/node/libwasmer_linux_amd64.so" "/app/devnet/"
COPY --from=builder "/go/mx-chain-go-mainnet/cmd/node/libwasmer_linux_amd64.so" "/app/mainnet/"
COPY --from=builder "/repos/mx-chain-devnet-config" "/app/devnet/config"
COPY --from=builder "/repos/mx-chain-mainnet-config" "/app/mainnet/config"
COPY --from=builder "/go/mx-chain-go-mainnet/cmd/keygenerator/keygenerator" "/app/"
COPY --from=builder "/repos/mx-chain-rosetta-docker-scripts/entrypoint.sh" "/app/"

EXPOSE 8080
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
