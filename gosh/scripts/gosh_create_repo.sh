#!/bin/bash
#	This file is part of Ever OS.
#	
#	Ever OS is free software: you can redistribute it and/or modify 
#	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
#	
#	Copyright 2019-2022 (c) EverX

if [ -z $1 ]; then
    echo "Usage: $0 DAO_NAME REPO_NAME <NETWORK>"
    exit
fi

CONTRACT=../goshwallet
CONTRACT_ABI=$CONTRACT.abi.json
CONTRACT_KEYS=$CONTRACT.keys.json
CONTRACT_ADDR=$(cat $CONTRACT.addr)
GOSH=../gosh
GOSH_ABI=$GOSH.abi.json
GOSH_ADDR=$(cat $GOSH.addr)

export TONOS_CLI=tonos-cli
export NETWORK=${3:-localhost}


if [ "$NETWORK" == "localhost" ]; then
    WALLET=wallets/localnode/SafeMultisigWallet
else
    WALLET=wallets/devnet/SafeMultisigWallet
fi

WALLET_ADDR=$CONTRACT_ADDR
WALLET_ABI=$CONTRACT_ABI
WALLET_KEYS=$CONTRACT_KEYS

SEVENTY_EVERS=70000000000
set -x
CALLED="deployRepository {\"nameRepo\":\"$2\"}"
$TONOS_CLI -u $NETWORK call $WALLET_ADDR $CALLED --abi $WALLET_ABI --sign $WALLET_KEYS > /dev/null || exit 1

DAO_ADDR=$($TONOS_CLI -j -u $NETWORK run $GOSH_ADDR getAddrDao "{\"name\":\"$1\"}" --abi $GOSH_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)
REPO_ADDR=$($TONOS_CLI -j -u $NETWORK run $GOSH_ADDR getAddrRepository "{\"dao\":\"$DAO_ADDRESS\",\"name\":\"$1\"}" --abi $GOSH_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)
#./giver.sh $REPO_ADDR $SEVENTY_EVERS

echo ===================== REPO =====================
echo DAO name: $1
echo DAO address: $DAO_ADDR
echo REPO name: $2
echo REPO addr: $REPO_ADDR
