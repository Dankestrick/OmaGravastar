"""Print every report the dongle sends on the settings channel for N seconds.
Replies to the web driver show up here too, so this reveals its commands."""
import os, select, sys, time
secs=float(sys.argv[1]) if len(sys.argv)>1 else 60
fd=os.open(sys.argv[2] if len(sys.argv)>2 else "/dev/hidraw2", os.O_RDONLY)
start=time.time(); seen={}
while time.time()-start<secs:
    if select.select([fd],[],[],0.5)[0]:
        d=os.read(fd,64); key=d.hex(" ")
        if d[1] in (0x03,0x04) and key in seen: continue  # skip repeated status polls
        seen[key]=1; print(f"{time.time()-start:6.1f}s {key}", flush=True)
