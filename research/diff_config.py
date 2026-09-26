"""Dump the config block and show bytes that differ from a baseline dump."""
import sys, os, subprocess
here=os.path.dirname(os.path.abspath(__file__))
base=open(sys.argv[1],"rb").read()
subprocess.run([sys.executable, os.path.join(here,"read_config.py")], stdout=subprocess.DEVNULL, check=True)
new=open(os.path.join(here,"config-dump.bin"),"rb").read()
if len(sys.argv)>2: open(sys.argv[2],"wb").write(new)
if b"\xee"*10 in new: sys.exit("reads failed: move the mouse to wake it, then run again")
ch=[(i,base[i],new[i]) for i in range(min(len(base),len(new))) if base[i]!=new[i]]
print(f"{len(ch)} byte(s) changed")
for i,a,b in ch: print(f"  0x{i:02x}: {a:02x} -> {b:02x}")
