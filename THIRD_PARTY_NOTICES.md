# Third-Party Notices

UMac is released under the MIT License (see `LICENSE`). The components below
are distributed with UMac under their own licenses.

## HyperMac

UMac is a fork of **HyperMac** v1.6.0 by Nguyễn Khắc Đại
([@khacdai24](https://github.com/khacdai24)) and contributors, published at
`github.com/mrgoose000000-gif/HyperMac` and stated by its README to be released
under the MIT License. The original copyright notice is retained in `LICENSE`.

The app icon (`Resources/AppIcon.icns`) and cover image (`Resources/cover.jpg`)
come from HyperMac.

## `Resources/smc` — SMC command-line tool (GPL-2.0)

`Resources/smc` is a prebuilt arm64 binary inherited from HyperMac. It matches
the `smc` command-line tool from the **smcFanControl** project
(Copyright (C) 2006 devnull and contributors), which is licensed under the
**GNU General Public License, version 2** (or, at your option, any later version).

- Source code: <https://github.com/hholtmann/smcFanControl/tree/master/smc-command>
- License text: `LICENSES/GPL-2.0.txt`

UMac does not link against this tool. It is a separate program that UMac's
optional battery-charge helper (`Resources/umac-power`) runs as its own process,
on Apple Silicon only. Its GPL-2.0 license applies to that binary alone and does
not change the MIT license of the rest of UMac.

If you redistribute UMac builds that include `Resources/smc`, you must also make
its corresponding source code available under GPL-2.0 (the link above, or a copy).
