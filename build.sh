#!/bin/bash -eu
set -o pipefail
{

version="$(git describe --tags)"
echo "$version"


# find-replace in _server.pbl
sed -i -e "s/version=.*$/version=\"$version\"/" _server.pbl


# update /target/version.txt
mkdir -p target
echo -n "$version" > target/version.txt


# strip out html tags and save
description="$(sed -e 's/<[^>]*>//g' doc/objectives_note.html)"
# update _server.pbl description
sed -i '/email/,$!d' _server.pbl
printf '%s%s\n"\n%s' '
# THIS FILE IS EDITED by build.sh

author="Vasya Novikov, Blitzmerker, piezocuttlefish"
description="' "$description" "$(cat _server.pbl)" > _server.pbl

}; exit 0
