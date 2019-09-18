#! /bin/bash

set -e

# ensure tz repository

tz="../examples/tz"

if [ ! -d "$tz/.git" ]; then
    git clone https://github.com/eggert/tz.git "$tz"
else
    git -C "$tz" checkout master && git -C "$tz" pull
fi

# make tz data

version=$(git -C "$tz" describe --tags --abbrev=0)
output="$(pwd -P)/zoneinfo"
start=-2208988800 # 1900-01-01
end=2524608000 # 2050-01-01

git -C "$tz" -c advice.detachedHead=false checkout $version
echo "Compiling tz data..."
make -C "$tz" --quiet install_data DESTDIR="$output" TZDIR="" REDO=posix_only ZFLAGS="-b fat -r @$start/@$end"
git -C "$tz" checkout master

# make zones list

zones="$output/zones.text"

cat "$tz/zone1970.tab" | grep -v "^#" | cut -f3 | sort > "$zones"

# remove TZif files not on the zones list

find "$output" -type f -not -name *.text | grep -F -v -f "$zones" | xargs rm
find "$output" -type d -empty -delete

# make elm file

elm make Zones.elm --output="zones.html"
