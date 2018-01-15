#!/bin/bash -eu
set -o pipefail
{

mkdir -p target


# remove newline, cut out commit hash
git describe --tags | cut -d '-' -f -2 | tr -d '\n' | tee target/version.txt


lua build/docs_to_txt.lua > target/about.txt


}; exit 0