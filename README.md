Lua Function Script for EdgeTX.

- Creates a telemetry sensor **Vspd** (m/s)
- Based on telemetry sensor **Alt** (meters)
- Can be used as Vario source in EdgeTX
- Optimized for low noise and low latency

## Installation

Copy the provided Lua script to
SCRIPTS/FUNCTIONS/
on a transmitter running EdgeTX (with a 4-in-1 RF module).

Bind the transmitter to a FlySky receiver with a FS-CAT01 sensor connected.
(For receivers such as the FS-IA6B, the correct protocol is “FlySky2A”.)

On the Special Functions page, create the following entries (see screenshot):

ON → Lua Script → FSvrio ✓

[Any switch] → Vario ✓

After running “Discover new sensors” on the Telemetry page, a sensor named “Vspd” should appear.

On the Telemetry page, edit the “Alt” sensor and enable the “Filter” option at the bottom.

Scroll down on the Telemetry page and set Vario Source to “Vspd”.

Set the Range to ±5 (recommended).

Set the Center to approximately ±1.0.

If you encounter an error code when running the Lua script, try formatting the SD card using the official SD Card Formatter:
https://www.sdcard.org/downloads/formatter/
