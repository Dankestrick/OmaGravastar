import os, select, time
RID=0x08
def pkt(cmd):
    p=bytearray(16); p[0]=cmd; p[15]=(0x55-(RID+sum(p[:15])))&0xff
    return bytes([RID])+bytes(p)
def txn(fd,cmd,t=0.7):
    os.write(fd,pkt(cmd)); end=time.time()+t
    while time.time()<end:
        r,_,_=select.select([fd],[],[],max(0,end-time.time()))
        if not r: return None
        d=os.read(fd,64)
        if d[0]==RID and d[1]==cmd: return d[1:]
fd=os.open("/dev/hidraw2",os.O_RDWR); start=time.time(); last=None
while time.time()-start<60:
    o=txn(fd,0x03); on=o.hex(' ') if o else None
    if on!=last: print(f"{time.time()-start:5.1f}s online: {on}",flush=True); last=on
    b=txn(fd,0x04)
    if b:
        print(f"{time.time()-start:5.1f}s battery: {b.hex(' ')}",flush=True)
        f=txn(fd,0x12); print(f"firmware: {f.hex(' ') if f else None}"); break
    time.sleep(0.5)
os.close(fd)
