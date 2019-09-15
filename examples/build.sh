#! /bin/bash

set -e

# ensure tz repository

if [ ! -d tz/.git ]; then
    git clone https://github.com/eggert/tz.git
else
    git -C tz checkout master && git -C tz pull
fi

# check latest version of tz

version=$(git -C tz describe --tags --abbrev=0)
output="$(pwd -P)/dist/$version"

if [ -d "$output" ]; then
    echo ""
    echo "Existing build at 'dist/$version' is current."
    echo ""
    exit 0
fi

# make tz data

start=$(date --date="1970-01-01" --utc +%s)
end=$(date --date="2038-01-01" --utc +%s)

git -C tz -c advice.detachedHead=false checkout $version
echo "Compiling tz data..."
make -C tz install_data DESTDIR="$output" TZDIR="" REDO=posix_only ZFLAGS="-b slim -r @$start/@$end"
git -C tz checkout master

# make elm file

elm make GetZone.elm --output="getzone.html"
