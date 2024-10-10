# v5 Data Recovery for 0L

This project provides a set of instructions and a script to recover and rebuild the database for a v5 0L node. The process automates the restoration of epoch backups and the recovery of the node’s state.

## Prerequisites

Ensure that you are running a Linux distribution with the following installed:

- Git
- Build essentials (CMake, Clang, LLVM, etc.)
- OpenSSL 1.1.1
- JQ
- Rust (stable)

## Steps to Install Dependencies

The following dependencies are required to build the v5 binaries and restore epochs:

```bash
# Dependencies
sudo apt install -y git jq build-essential cmake clang llvm libgmp-dev pkg-config libssl-dev lld

# OpenSSL (for Ubuntu Server 22.04)
cd ~
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl-dev_1.1.1f-1ubuntu2_amd64.deb
sudo dpkg -i libssl-dev_1.1.1f-1ubuntu2_amd64.deb

# Cargo
rustup self uninstall -y
rm -rf $HOME/.cargo $HOME/.rustup
unset RUSTC_WRAPPER
unset RUSTC_WORKSPACE_WRAPPER
sudo apt remove rustc
curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable -y
source "$HOME/.cargo/env"
rustup default stable && rustup update
```

## Build the v5 Binaries and Recover Epochs

To recover the database for a v5 node, you need the dependencies above and then you can run the recovery script.

This will build the v5 binaries from source and download the snapshots.

To recover epochs, clone this repo, determine the epochs, and run the recovery script.

```
cd $HOME
git clone https://github.com/0LNetworkCommunity/v5-data-recovery
cd ./v5-data-recovery

# Example: Restore epochs 1 through 10
EPOCH_START=1 EPOCH_END=10 ./recover_v5_data.sh
```

## Script Details (Recovery)

The main recovery process is handled by the following script, `recover_v5_data.sh`. The script performs the following actions for each epoch:

1. Makes the directories if they do not exist
2. Copies the genesis.blob and fullnode config
3. Extracts the epoch backup
4. Restores epoch-ending data
5. Restores transactions for the epoch
6. Restores the state snapshot (epoch 1 might cause problems as it lacks a state snapshot, just run a second time)
7. Sets the waypoint for the node
8. Prompts before starting the node

## Running the Node

Once the database recovery is complete, the script will ask if you start the node, which uses:

```
RUST_LOG=info ${BIN_PATH}/diem-node -f $HOME/.0L/fullnode.node.yaml
```

This will start your v5 node with the recovered data. The JSON RPC is available on port 8080 by default.

## License

This project is licensed under the terms of the [MIT License](LICENSE).
