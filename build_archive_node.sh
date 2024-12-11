### v5 Data Recovery

# Settings
export PROJECT_DIR=$HOME/v5-data-recovery
export EPOCH_START=${EPOCH_START:-1}
export EPOCH_END=${EPOCH_END:-692}
export EPOCH_ARCHIVE=epoch-archive-v5
export NEW_EPOCH_ARCHIVE=$NEW_EPOCH_ARCHIVE-rebuilt

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
rm -rf $PROJECT_DIR/db
# download but only the first 100 MB to test this
#curl -o 0L.archive.tar http://home.gouin.io/0L.archive.tar
#curl -r 0-100000000 -o 0L.archive.tar http://home.gouin.io/0L.archive.tar
#tar -xvf 0L.archive.tar
tar -xvf gnudrew_0L.archive.tar
rm -rf $DB_PATH
cp -rf $PROJECT_DIR/db $DB_PATH

# start the node and and grab the pid
RUST_LOG=info ${BIN_PATH}/diem-node -f $DATA_PATH/fullnode.node.yaml &
export NODE_PID=$!

# clone the new repo and build the
cd $HOME
rm -rf $NEW_EPOCH_ARCHIVE
git clone $NEW_EPOCH_ARCHIVE
cd $NEW_EPOCH_ARCHIVE

# set the archive path as the new epoch archive
export ARCHIVE_PATH=$HOME/$NEW_EPOCH_ARCHIVE
export URL="http://localhost"
export TRANS_LEN=1


# Backup each epoch
for EPOCH in $(seq $EPOCH_START $EPOCH_END); do
    echo "Backing up epoch $EPOCH"
    
    rm -rf $EPOCH.tar.gz

    # Create the archive
    mkdir -p ${ARCHIVE_PATH}/${EPOCH}
    
    # Backup the epoch ending
    export PREVIOUS_EPOCH=$((EPOCH - 1))
    ${BIN_PATH}/db-backup one-shot backup --backup-service-address ${URL}:6186 epoch-ending --start-epoch ${PREVIOUS_EPOCH} --end-epoch ${EPOCH} local-fs --dir ${ARCHIVE_PATH}/${EPOCH}

    # Get the epoch height
    VERSION=$(db-backup one-shot query node-state | cut -d ":" -d "," -f 2 | cut -d ":" -f 2| xargs)
    echo "Epoch $EPOCH has version $VERSION"
    exit

    # Backup transaction
    ${BIN_PATH}/db-backup one-shot backup --backup-service-address ${URL}:6186 transaction --num_transactions ${TRANS_LEN} --start-version ${VERSION} local-fs --dir ${ARCHIVE_PATH}/${EPOCH}

    # Backup state snapshot
    ${BIN_PATH}/db-backup one-shot backup --backup-service-address ${URL}:6186 state-snapshot --state-version ${VERSION} local-fs --dir ${ARCHIVE_PATH}/${EPOCH}/${VERSION}

    # Compress the archive
    tar -czvf $EPOCH.tar.gz ${ARCHIVE_PATH}/${EPOCH}

    echo "Epoch $EPOCH backup complete."
done

# Kill the node
kill $NODE_PID
echo "Node killed."