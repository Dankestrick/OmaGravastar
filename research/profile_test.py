"""Switch profiles (command 0x0f), dump the settings and shortcut blocks for
each, and switch back to the profile that was active."""
import os, select, sys, time, json
RID=0x08
def pkt(cmd, addr=0, data=b"", n=None):
    p=bytearray(16); p[0]=cmd; p[2]=addr>>8; p[3]=addr&0xff
    p[4]=len(data) if n is None else n; p[5:5+len(data)]=data
    p[15]=(0x55-(RID+sum(p[:15])))&0xff; return bytes([RID])+bytes(p)
def txn(fd, raw, cmd, addr=None):
    for _ in range(4):
        while select.select([fd],[],[],0)[0]: os.read(fd,64)
        os.write(fd, raw); end=time.time()+0.7
        while time.time()<end:
            if not select.select([fd],[],[],max(0,end-time.time()))[0]: break
            d=os.read(fd,64)
            if d[0]==RID and d[1]==cmd and (addr is None or (d[3]<<8|d[4])==addr): return d[1:17]
        time.sleep(0.2)
    sys.exit(f"no reply to 0x{cmd:02x}")
def dump(fd, start, length):
    out=bytearray()
    for a in range(start, start+length, 10):
        n=min(10, start+length-a); r=txn(fd, pkt(0x08,a,n=n), 0x08, a); out+=r[5:5+n]
    return bytes(out)
def profile(fd): return txn(fd, pkt(0x0e), 0x0e)[5]
def set_profile(fd, p):
    r=txn(fd, pkt(0x0f, data=bytes([p])), 0x0f); time.sleep(0.3); return r
fd=os.open("/dev/hidraw2", os.O_RDWR)
start=profile(fd); print("active profile:", start+1)
blocks={}
for p in range(4):
    if p!=start: print("switch ->", p+1, set_profile(fd,p).hex(" "))
    assert profile(fd)==p, "profile did not switch"
    blocks[p]=(dump(fd,0,0xc0), dump(fd,0x100,6*32))
set_profile(fd,start); print("back to profile", profile(fd)+1)
os.close(fd)
base=blocks[start]
for p in range(4):
    if p==start: continue
    diff=[i for i in range(0xc0) if blocks[p][0][i]!=base[0][i]]
    sdiff=[i for i in range(6*32) if blocks[p][1][i]!=base[1][i]]
    print(f"profile {p+1} vs {start+1}: settings differ at {[hex(i) for i in diff]} | shortcut area differs at {len(sdiff)} bytes")
json.dump({str(p+1): [b[0].hex(), b[1].hex()] for p,b in blocks.items()}, open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"profiles-dump.json"),"w"))
