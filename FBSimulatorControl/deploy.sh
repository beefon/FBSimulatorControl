#!/bin/bash

set -x

storage_url=$1
credentials=$2

([ -z "$storage_url" ] || [ -z "$credentials" ]) && echo "Usage: deploy.sh http://path.to/host user:password" && exit 1

timestamp=$(date +%Y%m%dT%H%M%S)

temp_folder=/tmp/$(uuidgen)

script_root=$(builtin cd "$(dirname "$0")" && pwd)

upload() {
    what=$1
    
    curl \
        -X PUT \
        -u "$credentials" \
        "$storage_url/$what/${what}_${timestamp}.zip" \
        -T "$temp_folder/$what.zip"
}

build() {
    what=$1
    
    output="$temp_folder/$what"
    
    "$script_root/build.sh" fbsimctl build "$output"
    
    mv "$output/bin/$what" "$output"
    mv "$output/Frameworks"/* "$output"
    
    rm -rf "$output/bin"
    rm -rf "$output/Frameworks"
    
    cd "$output"
    zip -r "$temp_folder/$what.zip" *
    cd -
}

build fbxctest
build fbsimctl

upload fbxctest
upload fbsimctl
