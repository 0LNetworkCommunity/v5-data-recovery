### v5 Data Recovery

# Settings
export PROJECT_DIR=$HOME/v5-data-recovery
export EPOCH_START=${EPOCH_START:-1}
export EPOCH_END=${EPOCH_END:-10}

# v5 Epoch Recovery project directory
export DATA_PATH=$HOME/.0L
export DB_PATH=$DATA_PATH/db
mkdir -p $DATA_PATH
mkdir -p $PROJECT_DIR

# Prepare some v5 node files
cp $PROJECT_DIR/genesis.blob $DATA_PATH/
cp $PROJECT_DIR/fullnode.node.yaml $DATA_PATH/
sed -i "s|YOUR_HOME_DIR|$HOME|g" "$DATA_PATH/fullnode.node.yaml"


# Build the v5 binaries
cd $PROJECT_DIR/
git clone https://github.com/0LNetworkCommunity/libra-legacy-v6
cd ./libra-legacy-v6
git checkout tags/v5.2.0
git pull
cargo build --release
cargo build -p backup-cli --release
export BIN_PATH=$PROJECT_DIR/libra-legacy-v6/target/release

# Get the backups
cd $PROJECT_DIR
wget https://github.com/0LNetworkCommunity/epoch-archive-v5/archive/refs/heads/main.zip
sudo apt install -y unzip
unzip main.zip
export ARCHIVE_PATH=$PROJECT_DIR/epoch-archive-v5-main
cd $ARCHIVE_PATH
ls


# Restore the epochs
# you can also copy/paste this
for EPOCH in $(seq $EPOCH_START $EPOCH_END); do
    echo "Restoring epoch $EPOCH"
    
    # Extract the backup
    cd $ARCHIVE_PATH
    tar -xvf $EPOCH.tar.gz
    
    # Restore the epoch ending
    ${BIN_PATH}/db-restore --target-db-dir ${DB_PATH} epoch-ending \
    --epoch-ending-manifest ${ARCHIVE_PATH}/${EPOCH}/epoch_ending_${EPOCH}*/epoch_ending.manifest \
    local-fs --dir ${ARCHIVE_PATH}/${EPOCH}
    
    # Extract epoch info
    export EPOCH_WAYPOINT=$(jq -r ".waypoints[0]" ${ARCHIVE_PATH}/${EPOCH}/ep*/epoch_ending.manifest)
    export EPOCH_HEIGHT=$(echo ${EPOCH_WAYPOINT} | cut -d ":" -f 1)
    
    # Restore the transaction
    ${BIN_PATH}/db-restore --target-db-dir ${DB_PATH} transaction \
    --transaction-manifest ${ARCHIVE_PATH}/${EPOCH}/transaction_${EPOCH_HEIGHT}*/transaction.manifest \
    local-fs --dir ${ARCHIVE_PATH}/${EPOCH}
    
    # Restore the state
    ${BIN_PATH}/db-restore --target-db-dir ${DB_PATH} state-snapshot \
    --state-manifest ${ARCHIVE_PATH}/${EPOCH}/state_ver_${EPOCH_HEIGHT}*/state.manifest \
    --state-into-version ${EPOCH_HEIGHT} local-fs --dir ${ARCHIVE_PATH}/${EPOCH}
    
    # Restore the waypoint
    echo ${EPOCH_WAYPOINT} > ${DATA_PATH}/restore_waypoint

    echo "Epoch $EPOCH restoration complete."
done


# Prompt the user if they want to run the node
read -p "Do you want to run the node? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Run the node
    RUST_LOG=info ${BIN_PATH}/diem-node -f $HOME/.0L/fullnode.node.yaml
fi