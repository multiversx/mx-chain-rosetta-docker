FROM golang:1.17.6 as builder

ARG ROSETTA_TAG=v0.3.4
ARG ROSETTA_DOCKER_SCRIPTS_TAG=v0.2.1
ARG CONFIG_DEVNET_TAG=D1.3.48.0-hf-fix
ARG CONFIG_MAINNET_TAG=release-v1.3.48.0

# Clone repositories
WORKDIR /repos
RUN git clone https://github.com/ElrondNetwork/rosetta-docker-scripts.git --branch=${DOCKER_SCRIPTS_TAG} --depth=1
RUN git clone https://github.com/ElrondNetwork/elrond-config-devnet --branch=${CONFIG_DEVNET_TAG} --single-branch --depth=1
RUN git clone https://github.com/ElrondNetwork/elrond-config-mainnet --branch=${CONFIG_MAINNET_TAG} --single-branch --depth=1

WORKDIR /go
RUN git clone https://github.com/ElrondNetwork/elrond-go.git --branch=$(cat /workspace/elrond-config-devnet/binaryVersion | sed 's/tags\///') --single-branch elrond-go-devnet
RUN git clone https://github.com/ElrondNetwork/elrond-go.git --branch=$(cat /workspace/elrond-config-mainnet/binaryVersion | sed 's/tags\///') --single-branch elrond-go-mainnet
RUN git clone https://github.com/ElrondNetwork/rosetta.git --branch=${ROSETTA_TAG} --depth=1

# Build rosetta
WORKDIR /go/rosetta/cmd/rosetta
RUN go build

# Build node
WORKDIR /go/elrond-go-devnet/cmd/node
RUN go build -i -v -ldflags="-X main.appVersion=$(git describe --tags --long --dirty --always)"
RUN cp /go/pkg/mod/github.com/!elrond!network/arwen-wasm-vm@$(cat /go/elrond-go-devnet/go.mod | grep arwen-wasm-vm | sed 's/.* //' | tail -n 1)/wasmer/libwasmer_linux_amd64.so /lib/libwasmer_linux_amd64.so

WORKDIR /go/elrond-go-mainnet/cmd/node
RUN go build -i -v -ldflags="-X main.appVersion=$(git describe --tags --long --dirty --always)"
RUN cp /go/pkg/mod/github.com/!elrond!network/arwen-wasm-vm@$(cat /go/elrond-go-mainnet/go.mod | grep arwen-wasm-vm | sed 's/.* //' | tail -n 1)/wasmer/libwasmer_linux_amd64.so /lib/libwasmer_linux_amd64.so

# Build key generator
# TODO: For elrond-go v1.4.0 (upcoming), use the flag `--no-key` instead of using the keygenerator
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

# Copy node:
# We are sharing libwasmer among "elrond-go-devnet" and "elrond-go-mainnet" (no workaround on this yet - left as future work).
COPY --from=builder "/lib/libwasmer_linux_amd64.so" "/lib/libwasmer_linux_amd64.so"
COPY --from=builder "/repos/elrond-config-devnet" "/elrond/devnet/node/config/"
COPY --from=builder "/go/elrond-go-devnet/cmd/node/node" "/elrond/devnet/node/"
COPY --from=builder "/repos/elrond-config-mainnet" "/elrond/mainnet/node/config/"
COPY --from=builder "/go/elrond-go-mainnet/cmd/node/node" "/elrond/mainnet/node/"

# Copy rosetta:
COPY --from=builder "/go/rosetta/cmd/rosetta" "/elrond/"

# Copy keygenerator:
COPY --from=builder "/go/elrond-go-mainnet/cmd/keygenerator/keygenerator" "/elrond/keygenerator"

EXPOSE 8080
