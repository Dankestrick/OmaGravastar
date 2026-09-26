# Protocol research

How the Mercury X Pro's settings were mapped. None of this is needed to run
the plugin.

| File | What it is |
| --- | --- |
| `probe_status.py` | Read-only handshake, online, battery and firmware queries |
| `wake_and_battery.py` | Polls until the mouse wakes, then reads battery |
| `read_config.py` | Dumps the settings block (`0x00`-`0xff`) to `config-dump.bin` |
| `diff_config.py` | Dumps again and prints the bytes that changed since a saved dump |
| `sniff.py` | Prints every report the dongle sends, including replies to Gravastar's web driver |
| `write_brightness_test.py` | The first write test: brightness with read-back |
| `dump-*.bin` | Saved dumps, one per change made in the web driver |
| `sniff-page-load.txt` | Everything the web driver asks when its page loads |

Method: change one setting in Gravastar's web driver, run `diff_config.py`
against the previous dump, and note which bytes moved. Settings outside the
block (Long distance mode) were found with `sniff.py`.
