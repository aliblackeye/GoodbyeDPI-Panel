# Third-party notices

This repository bundles unmodified binaries of the following projects so the
panel works without a separate download. The panel itself (HTA, `.cmd`,
`scripts/*.ps1`) is MIT-licensed (see `LICENSE`). The bundled binaries keep
their own licences, whose full texts are in `licenses/`.

## GoodbyeDPI 0.2.3rc3

- Author: ValdikSS
- Licence: Apache License 2.0 — `licenses/LICENSE-goodbyedpi.txt`
- Source: https://github.com/ValdikSS/GoodbyeDPI (tag `0.2.3rc3`,
  commit `8a0bef08bfca05be0d4dfb06509be6309efdc1e4`)
- Release page: https://github.com/ValdikSS/GoodbyeDPI/releases/tag/0.2.3rc3
- Archive: `goodbyedpi-0.2.3rc3-2.zip`, 1,084,060 bytes,
  SHA-256 `37f96b32d050dadcc930a639eba68e1ccd57ed5c04a5f77dfca908f01905a4c5`
  (computed after download from the URL below. Upstream publishes no checksum.)
  https://github.com/ValdikSS/GoodbyeDPI/releases/download/0.2.3rc3/goodbyedpi-0.2.3rc3-2.zip
- Why this release: it is the newest release ValdikSS has published (2024-09-14).
  GitHub marks it as a pre-release. The last release without that flag, 0.2.2
  (2022), has no `-7`/`-8`/`-9` modes, no `-q` and no TLS 1.2 record handshake fix.
  The panel's mode list relies on those.
- GoodbyeDPI also includes code under these licences:
  - uthash — BSD-style licence, `licenses/LICENSE-uthash.txt`
  - getline (NetBSD) — BSD-style licence, `licenses/LICENSE-getline.txt`

## WinDivert 2.2 (2.2.0-D, as shipped inside the GoodbyeDPI archive)

- Author: basil00
- Licence: dual — GNU LGPL v3 **or** GNU GPL v2, at your option. The LGPLv3,
  GPLv3 and GPLv2 texts are all in `licenses/LICENSE-windivert.txt` (copied from
  the WinDivert repository at tag `v2.2.0`).
- Source: https://github.com/basil00/WinDivert (tag `v2.2.0`) and
  https://reqrypt.org/windivert.html
- Files: `WinDivert.dll`, `WinDivert64.sys`, `WinDivert32.sys`. The `.sys`
  drivers carry a valid Authenticode signature from "Cloudveil Technology Inc."
  The DLLs are not signed, as in upstream.

## Bundled files

Paths are relative to `bin/`. The same list is in `bin/SHA256SUMS.txt`.

| File | Bytes | SHA-256 |
|------|------:|---------|
| `x86_64/goodbyedpi.exe` | 101,888 | `8d412b094bb9c137ff25ba9a794d1122ecc84bb776debff6c249723a13cc31cd` |
| `x86_64/WinDivert.dll` | 47,104 | `6110bfa44667405179c3e15e12af1b62037e447ed59b054b19042032995e6c7e` |
| `x86_64/WinDivert64.sys` | 92,120 | `e69b5ba3f0cd6cfb2983e442636e7f0b342b61b15264b0328317d4559c82cf50` |
| `x86/goodbyedpi.exe` | 100,864 | `66e202c9fce9e769e2bc791b7fd6f56f21eab59f607f4ed0724e0c68c430dd1f` |
| `x86/WinDivert.dll` | 43,008 | `625ffdd95bfabff32d0e8a95beabcd303c01c8bba73b90402d4e84d6e15dd8e5` |
| `x86/WinDivert32.sys` | 77,784 | `29ca5ceb59c9c6993a349e82b1fd46078e6f8a302764153ab84fa22e382fcdca` |
| `x86/WinDivert64.sys` | 92,120 | `e69b5ba3f0cd6cfb2983e442636e7f0b342b61b15264b0328317d4559c82cf50` |

Every file is byte-identical to the matching file in the archive above.
Nothing was modified or rebuilt.

To verify the files, open PowerShell in the repository folder and run:

```powershell
Get-ChildItem bin -Recurse -File -Exclude SHA256SUMS.txt | Get-FileHash -Algorithm SHA256
```
