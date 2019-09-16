# tzif

Decode [TZif][tzif] (Time Zone Information Format) files into `Time.Zone` values for using with [`elm/time`][elmtime].

## Installation

```sh
elm install justinmimbs/tzif
```

## Overview

This package provides a single bytes decoder:

```elm
decode : Bytes.Decode.Decoder Time.Zone
```

## Why would I need this?

If you need `Time.Zone` values for using with `elm/time`, then one approach is to fetch the required zones at runtime. See [examples/GetZone.elm][getzone] for an example that fetches the local time zone.

## Where do I get TZif files?

You can use the [IANA Time Zone Database][tzdb] to build a set of TZif files for all time zones.

See [examples/build.sh][build] for an example that does the following:

- clones the IANA Time Zone Database [repository][tz]
- compiles TZif files for the latest release

The script installs TZif files to `./dist/<version>/`, where `<version>` is the latest release (e.g. `2019c`).

The script builds TZif files that contain all transitions between 1970 and 2037. However, if your application only uses timestamps after, say, 2010, then you can build smaller TZif files by [limiting the range][buildrange] accordingly.

**Note:** a Unix-like computer usually has a set of TZif files installed at `/usr/share/zoneinfo/`; however, I would not recommend distributing those to clients of your web application because they are likely to be bloated by backward-compatibility and contain a vast range of transition times. If you build your own, then you can build smaller files for just the time range you need.

[elmtime]: https://package.elm-lang.org/packages/elm/time/latest/
[tzif]: https://tools.ietf.org/html/rfc8536
[tzdb]: https://www.iana.org/time-zones
[tz]: https://github.com/eggert/tz
[getzone]: https://github.com/justinmimbs/tzif/blob/master/examples/GetZone.elm
[build]: https://github.com/justinmimbs/tzif/blob/master/examples/build.sh
[buildrange]: https://github.com/justinmimbs/tzif/blob/master/examples/build.sh#L27-L28
