FROM golang:1.20.7 as builder

ARG ROSETTA_DEVNET_TAG=v0.4.3
ARG ROSETTA_MAINNET_TAG=v0.4.3
ARG ROSETTA_DOCKER_SCRIPTS_TAG=v0.2.6

ARG CONFIG_DEVNET_TAG=D1.5.13.0
ARG CONFIG_MAINNET_TAG=v1.5.13.0

# Install Python dependencies, necessary for "adjust_binary.py" and "adjust_observer_src.py"
RUN apt-get update && apt-get -y install python3-pip && pip3 install toml --break-system-packages

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

# Adjust node source code
RUN python3 /repos/mx-chain-rosetta-docker-scripts/adjust_observer_src.py --src=/go/mx-chain-go-devnet --max-headers-to-request-in-advance=150 && \
    python3 /repos/mx-chain-rosetta-docker-scripts/adjust_observer_src.py --src=/go/mx-chain-go-mainnet --max-headers-to-request-in-advance=150

# Adjust node configuration files
RUN python3 /repos/mx-chain-rosetta-docker-scripts/adjust_config.py --mode=main --file=/repos/mx-chain-devnet-config/config.toml --api-simultaneous-requests=16384 --sync-process-time-milliseconds=5000 && \
    python3 /repos/mx-chain-rosetta-docker-scripts/adjust_config.py --mode=prefs --file=/repos/mx-chain-devnet-config/prefs.toml && \
    python3 /repos/mx-chain-rosetta-docker-scripts/adjust_config.py --mode=main --file=/repos/mx-chain-mainnet-config/config.toml --api-simultaneous-requests=16384 && \
    python3 /repos/mx-chain-rosetta-docker-scripts/adjust_config.py --mode=prefs --file=/repos/mx-chain-mainnet-config/prefs.toml

# Build node (devnet)
WORKDIR /go/mx-chain-go-devnet/cmd/node
RUN go build -v -ldflags="-X main.appVersion=$(git --git-dir /repos/mx-chain-devnet-config/.git describe --tags --long --dirty --always)"
RUN cp /go/pkg/mod/github.com/multiversx/$(cat /go/mx-chain-go-devnet/go.mod | grep mx-chain-vm-v | sort -n | tail -n -1| awk -F '/' '{print$3}'| sed 's/ /@/g')/wasmer/libwasmer_linux_amd64.so /go/mx-chain-go-devnet/cmd/node/libwasmer_linux_amd64.so

# Build node (mainnet)
WORKDIR /go/mx-chain-go-mainnet/cmd/node
RUN go build -v -ldflags="-X main.appVersion=$(git --git-dir /repos/mx-chain-mainnet-config/.git describe --tags --long --dirty --always)"
RUN cp /go/pkg/mod/github.com/multiversx/$(cat /go/mx-chain-go-mainnet/go.mod | grep mx-chain-vm-v | sort -n | tail -n -1| awk -F '/' '{print$3}'| sed 's/ /@/g')/wasmer/libwasmer_linux_amd64.so /go/mx-chain-go-mainnet/cmd/node/libwasmer_linux_amd64.so

# ===== SECOND STAGE ======
FROM ubuntu:22.04

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
COPY --from=builder "/repos/mx-chain-rosetta-docker-scripts/entrypoint.sh" "/app/"

EXPOSE 8080
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
