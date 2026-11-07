# Physical-device validation — 2026-11-07

## Single-page release motion

Device: Samsung SM-S948N, Android 17, single-page layout, default medium profile.
The system animator duration scale was zero. The validation fixture used the
default `preserveSwipeSettleOnReducedMotion: true` configuration.

| Released gesture | Settle time | Page | Active frames | Layer retained until endpoint |
| --- | ---: | --- | ---: | --- |
| Forward, return | 193 ms | 3 → 3 | 22 | Yes |
| Forward, complete | 416 ms | 3 → 4 | 46 | Yes |
| Backward, return | 187 ms | 4 → 4 | 22 | Yes |
| Backward, complete | 401 ms | 4 → 3 | 45 | Yes |

The 135 active frames moved monotonically toward the selected endpoint. The
recording was visually reviewed for the post-release moving sheet. Evidence:
`build/device-single-20261107/verification-report.json`,
`release-four-cases.txt`, and `release-verified.mp4` in the same directory.

## Ordinary ADB bulk transfer

The USB receive fault was localized to the original PC USB path. With the same
phone, cable, Samsung driver, and SDK ADB, changing the physical connection path
restored ordinary `adb pull` transfers.

| Item | Failing path | Working rear motherboard path |
| --- | --- | --- |
| Upstream hub | Genesys `VID_05E3&PID_0610` | ASMedia `VID_174C&PID_2074` |
| xHCI PCI path suffix | `PCI(0800)#PCI(0001)` | `PCI(0800)#PCI(0003)` |
| USB path suffix | `USBROOT(0)#USB(5)#USB(1)` | `USBROOT(0)#USB(2)#USB(1)` |
| 8 MiB random file / recording | Repeated resets | Six of six pulls passed |
| 128 MiB random file | Not used for baseline | Five of five pulls passed |

The working rear port still has an onboard ASMedia hub. The evidence therefore
supports a fault in the original connection path, without identifying the
Genesys chip, physical port, or upstream controller as an individually proven
defective component. The resolution is to retain the verified rear port.

### Failure evidence

The native ADB USB trace showed successful payload reads of 65,552 and 101,517
bytes, but failed reads for payloads of 167,061 and 196,632 bytes. WinUSB returned
Windows error 31. ADB then closed and rediscovered the transport. File extension
and sync compression were excluded by repeating with renamed files and `-Z`.
The behavior depended on how stream data was aggregated into USB requests;
successful zero-filled files alone did not demonstrate a healthy bulk path.

A Windows ETW trace captured the failed phone URB with USB status `0xC0000011`
(`USBD_STATUS_XACT_ERROR`), followed by canceled requests and a port disconnect.
The code is defined in Microsoft's
[USB driver header](https://github.com/microsoft/win32metadata/blob/main/generation/WinSDK/RecompiledIdlHeaders/shared/usb.h).
Only transfer headers and status metadata were enabled, following Microsoft's
[USB ETW capture guidance](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/how-to-capture-a-usb-event-trace).

Evidence under `build/device-single-20261107/rootcause/`:

- `repeat-matrix.json`: all 12 pre-change random/video pulls failed.
- `foreground-trace.log`: native USB request lengths and Windows errors.
- `usb-transfer.etl`, `urb-errors.xml`, `urb-failure-status.json`: Windows USB status.
- `rear-direct-results.json`: all six post-change pulls and matching hashes.
- `bulk-validation.json`, `bulk-validation-server.log`: large transfer verification.

### Bulk verification

ADB: original SDK version `37.0.0-14910828`, native USB backend, burst mode off,
tracing off. The original Samsung composite/WinUSB drivers and `mtp,adb`
configuration were retained.

Test file: 134,217,728 bytes of device-generated random data. SHA-256:

```text
c35fa1ab9e09e37f7c3c7016e4a30c68d962881c40ab187a7fce378b7ce46ba5
```

Three ordinary pulls and two `pull -Z` transfers all returned exit code zero,
the full byte count, and the same SHA-256 as the device file. ADB reported
40.2–40.7 MB/s. The server was deliberately restarted after the second transfer;
all remaining transfers passed. No chunk receiver, resume, or retry was used
inside any pull. The only transport termination in the verification log was
the deliberate server restart.

The large diagnostic file was removed from the phone after verification.
