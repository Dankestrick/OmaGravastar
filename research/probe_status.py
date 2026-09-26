import os, select, time
RID=0x08
def pkt(cmd):
    p=bytearray(16); p[0]=cmd; p[15]=(0x55-(RID+sum(p[:15])))&0xff
    return bytes([RID])+bytes(p)
fd=os.open("/dev/hidraw2", os.O_RDWR)
for name,cmd in [("handshake",0x01),("online",0x03),("battery",0x04),("firmware",0x12)]:
    os.write(fd,pkt(cmd)); end=time.time()+2.0; got=[]
    while time.time()<end:
        r,_,_=select.select([fd],[],[],max(0,end-time.time()))
        if not r: break
        d=os.read(fd,64); got.append(f"+{2-(end-time.time()):.2f}s {d.hex(' ')}")
    print(f"== {name}"); print("\n".join(got) or "   nothing")
os.close(fd)
