FROM golang:1.17.6 as builder

ARG ROSETTA_DEVNET_TAG=v0.3.4
ARG ROSETTA_MAINNET_TAG=v0.3.4
ARG ROSETTA_DOCKER_SCRIPTS_TAG=split-versions-20
ARG CONFIG_DEVNET_TAG=D1.3.48.0-hf-fix
ARG CONFIG_MAINNET_TAG=v1.3.48.0

# Clone repositories
WORKDIR /repos
RUN git clone https://github.com/ElrondNetwork/rosetta-docker-scripts.git --branch=${ROSETTA_DOCKER_SCRIPTS_TAG} --single-branch --depth=1
RUN git clone https://github.com/ElrondNetwork/elrond-config-devnet --branch=${CONFIG_DEVNET_TAG} --single-branch --depth=1
RUN git clone https://github.com/ElrondNetwork/elrond-config-mainnet --branch=${CONFIG_MAINNET_TAG} --single-branch --depth=1

WORKDIR /go
RUN git clone https://github.com/ElrondNetwork/elrond-go.git --branch=$(cat /repos/elrond-config-devnet/binaryVersion | sed 's/tags\///') --single-branch elrond-go-devnet
RUN git clone https://github.com/ElrondNetwork/elrond-go.git --branch=$(cat /repos/elrond-config-mainnet/binaryVersion | sed 's/tags\///') --single-branch elrond-go-mainnet
RUN git clone https://github.com/ElrondNetwork/rosetta.git --branch=${ROSETTA_DEVNET_TAG} --depth=1 rosetta-devnet
RUN git clone https://github.com/ElrondNetwork/rosetta.git --branch=${ROSETTA_MAINNET_TAG} --depth=1 rosetta-mainnet

# Build rosetta (devnet)
WORKDIR /go/rosetta-devnet/cmd/rosetta
RUN go build

# Build rosetta (mainnet)
WORKDIR /go/rosetta-mainnet/cmd/rosetta
RUN go build

# Build node (devnet)
WORKDIR /go/elrond-go-devnet/cmd/node
RUN go build -i -v -ldflags="-X main.appVersion=$(git describe --tags --long --dirty --always)"
RUN cp /go/pkg/mod/github.com/!elrond!network/arwen-wasm-vm@$(cat /go/elrond-go-devnet/go.mod | grep arwen-wasm-vm | sed 's/.* //' | tail -n 1)/wasmer/libwasmer_linux_amd64.so /go/elrond-go-devnet/cmd/node/libwasmer_linux_amd64.so

# Build node (mainnet)
WORKDIR /go/elrond-go-mainnet/cmd/node
RUN go build -i -v -ldflags="-X main.appVersion=$(git describe --tags --long --dirty --always)"
RUN cp /go/pkg/mod/github.com/!elrond!network/arwen-wasm-vm@$(cat /go/elrond-go-mainnet/go.mod | grep arwen-wasm-vm | sed 's/.* //' | tail -n 1)/wasmer/libwasmer_linux_amd64.so /go/elrond-go-mainnet/cmd/node/libwasmer_linux_amd64.so

# Build key generator
WORKDIR /go/elrond-go-mainnet/cmd/keygenerator
RUN go build .

# Adjust configuration files
RUN apt-get update && apt-get -y install python3-pip && pip3 install toml
RUN python3 /repos/rosetta-docker-scripts/adjust_config.py --mode=main --file=/repos/elrond-config-devnet/config.toml --api-simultaneous-requests=16384 && \
    python3 /repos/rosetta-docker-scripts/adjust_config.py --mode=prefs --file=/repos/elrond-config-devnet/prefs.toml && \
    python3 /repos/rosetta-docker-scripts/adjust_config.py --mode=main --file=/repos/elrond-config-mainnet/config.toml --api-simultaneous-requests=16384 && \
    python3 /repos/rosetta-docker-scripts/adjust_config.py --mode=prefs --file=/repos/elrond-config-mainnet/prefs.toml

# ===== SECOND STAGE ======
FROM ubuntu:20.04

COPY --from=builder "/go/rosetta-devnet/cmd/rosetta/rosetta" "/elrond/devnet/"
COPY --from=builder "/go/rosetta-mainnet/cmd/rosetta/rosetta" "/elrond/mainnet/"
COPY --from=builder "/go/elrond-go-devnet/cmd/node/node" "/elrond/devnet/"
COPY --from=builder "/go/elrond-go-mainnet/cmd/node/node" "/elrond/mainnet/"
COPY --from=builder "/go/elrond-go-devnet/cmd/node/libwasmer_linux_amd64.so" "/elrond/devnet/"
COPY --from=builder "/go/elrond-go-mainnet/cmd/node/libwasmer_linux_amd64.so" "/elrond/mainnet/"
COPY --from=builder "/repos/elrond-config-devnet" "/elrond/devnet/config"
COPY --from=builder "/repos/elrond-config-mainnet" "/elrond/mainnet/config"
COPY --from=builder "/go/elrond-go-mainnet/cmd/keygenerator/keygenerator" "/elrond/"
COPY --from=builder "/repos/rosetta-docker-scripts/entrypoint.sh" "/elrond/"

EXPOSE 8080
WORKDIR /elrond
ENTRYPOINT ["/elrond/entrypoint.sh"]
