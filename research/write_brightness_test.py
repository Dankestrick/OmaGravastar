"""First write test: set lighting brightness to one slider value, verify by reading back."""
import os, select, sys, time
RID=0x08; ADDR=0xa0; LEN=7
def pkt(cmd, addr=0, data=b"", n=None):
    p=bytearray(16); p[0]=cmd; p[2]=addr>>8; p[3]=addr&0xff
    p[4]=len(data) if n is None else n; p[5:5+len(data)]=data
    p[15]=(0x55-(RID+sum(p[:15])))&0xff; return bytes([RID])+bytes(p)
def txn(fd, raw, cmd, t=0.7):
    for _ in range(4):
        os.write(fd, raw); end=time.time()+t
        while time.time()<end:
            r,_,_=select.select([fd],[],[],max(0,end-time.time()))
            if not r: break
            d=os.read(fd,64)
            if d[0]==RID and d[1]==cmd and (RID+sum(d[1:17]))&0xff==0x55: return d[1:17]
        time.sleep(0.3)
    sys.exit(f"no reply to 0x{cmd:02x}: move the mouse to wake it")
def read_record(fd):
    r=txn(fd, pkt(0x08,ADDR,n=LEN), 0x08)
    assert r[1]==0 and r[2]==0 and r[3]==ADDR and r[4]==LEN, r.hex(" ")
    return bytearray(r[5:5+LEN])
slider=int(sys.argv[1])
fd=os.open("/dev/hidraw2", os.O_RDWR)
rec=read_record(fd)
print("before:", rec.hex(" "), f"(brightness slider {rec[5]+1})")
if sum(rec)&0xff!=0x55: sys.exit("record checksum is wrong; not writing")
new=bytearray(rec); new[5]=slider-1; new[6]=(0x55-sum(new[:6]))&0xff
print("write: ", new.hex(" "))
w=txn(fd, pkt(0x07,ADDR,bytes(new)), 0x07)
print("reply: ", w.hex(" "), "OK" if w[1]==0 else "ERROR")
time.sleep(0.1)
after=read_record(fd)
print("after: ", after.hex(" "), f"(brightness slider {after[5]+1})", "MATCH" if after==new else "MISMATCH")
os.close(fd)
