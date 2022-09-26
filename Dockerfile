FROM golang:1.17.6 as builder

# Clone repositories
WORKDIR /repos
RUN git clone https://github.com/ElrondNetwork/rosetta-docker-scripts.git --branch=v0.2.0 --depth=1
# TODO: use tag after release
RUN git clone https://github.com/ElrondNetwork/elrond-config-devnet --branch=D1.3.42.0 --depth=1
# TODO: use tag after release
RUN git clone https://github.com/ElrondNetwork/elrond-config-mainnet --branch=v1.3.42.0 --depth=1
WORKDIR /go
# TODO: use tag after release
RUN git clone https://github.com/ElrondNetwork/elrond-go.git --branch=EN-13187-oldest-epoch-metric-plus-epoch-start --single-branch
RUN git clone https://github.com/ElrondNetwork/rosetta.git --branch=update-lib-refs --depth=1

# Build rosetta
WORKDIR /go/rosetta/cmd/rosetta
RUN go build

# Build node
WORKDIR /go/elrond-go/cmd/node
RUN go build -i -v -ldflags="-X main.appVersion=$(git describe --tags --long --dirty --always)"
RUN cp /go/pkg/mod/github.com/!elrond!network/arwen-wasm-vm@$(cat /go/elrond-go/go.mod | grep arwen-wasm-vm | sed 's/.* //' | tail -n 1)/wasmer/libwasmer_linux_amd64.so /lib/libwasmer_linux_amd64.so

# Build key generator
WORKDIR /go/elrond-go/cmd/keygenerator
RUN go build .

# Adjust configuration files
RUN apt-get update && apt-get -y install python3-pip && pip3 install toml
RUN python3 /repos/rosetta-docker-scripts/adjust_config.py --mode=main --file=/repos/elrond-config-devnet/config.toml --num-epochs-to-keep=1024 --api-simultaneous-requests=16384 && \
    python3 /repos/rosetta-docker-scripts/adjust_config.py --mode=prefs --file=/repos/elrond-config-devnet/prefs.toml && \
    python3 /repos/rosetta-docker-scripts/adjust_config.py --mode=main --file=/repos/elrond-config-mainnet/config.toml --num-epochs-to-keep=128 --api-simultaneous-requests=16384 && \
    python3 /repos/rosetta-docker-scripts/adjust_config.py --mode=prefs --file=/repos/elrond-config-mainnet/prefs.toml

# ===== SECOND STAGE ======
FROM ubuntu:20.04

COPY --from=builder "/go/rosetta/cmd/rosetta" "/elrond/"
COPY --from=builder "/go/elrond-go/cmd/node/node" "/elrond/"
COPY --from=builder "/go/elrond-go/cmd/keygenerator/keygenerator" "/elrond/"
COPY --from=builder "/lib/libwasmer_linux_amd64.so" "/lib/libwasmer_linux_amd64.so"
COPY --from=builder "/repos/elrond-config-devnet" "/elrond/config-devnet/"
COPY --from=builder "/repos/elrond-config-mainnet" "/elrond/config-mainnet/"
COPY --from=builder "/repos/rosetta-docker-scripts/entrypoint.sh" "/elrond/"

EXPOSE 8080
WORKDIR /elrond
ENTRYPOINT ["/elrond/entrypoint.sh"]
