#!/bin/bash
#
# build all in one file
#
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR=${DIR}/..

FINAL_SCRIPT=oo.sh
pushd $SRC_DIR
# generate tarFile
TAR_FILE=$(git rev-parse --short HEAD).tar.gz

#create tar file
tar czvf $TAR_FILE lib/

# make tar binary to base64
TMP_BIN=$(mktemp)
base64 $TAR_FILE > $TMP_BIN

rm -f $FINAL_SCRIPT
cat lib/oo-zbootstrap.sh >> $FINAL_SCRIPT
echo "__oo_payload=/tmp/$TAR_FILE" >> $FINAL_SCRIPT
echo "" >> $FINAL_SCRIPT
echo -n "echo \"" >> $FINAL_SCRIPT
cat $TMP_BIN >> $FINAL_SCRIPT
echo -n "\" | base64 -d > /tmp/$TAR_FILE" >> $FINAL_SCRIPT
echo  "System::Bootstrap" >> $FINAL_SCRIPT

#clean
rm -f $TMP_BIN
rm -f $TAR_FILE
popd
