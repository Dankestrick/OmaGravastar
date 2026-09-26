import os, select, time
RID=0x08
def pkt(cmd, addr=0, n=0):
    p=bytearray(16); p[0]=cmd; p[2]=addr>>8; p[3]=addr&0xff; p[4]=n
    p[15]=(0x55-(RID+sum(p[:15])))&0xff; return bytes([RID])+bytes(p)
def txn(fd,*a,t=0.7):
    os.write(fd,pkt(*a)); end=time.time()+t
    while time.time()<end:
        r,_,_=select.select([fd],[],[],max(0,end-time.time()))
        if not r: return None
        d=os.read(fd,64)
        if d[0]==RID and d[1]==a[0]: return d[1:]
fd=os.open("/dev/hidraw2",os.O_RDWR)
mem=bytearray(); bad=[]
for addr in range(0,0x100,10):
    for _ in range(4):
        r=txn(fd,0x08,addr,10)
        if r and r[1]==0 and r[2]==addr>>8 and r[3]==addr&0xff: break
        time.sleep(0.3)
    if not r or r[1]!=0 or r[2]!=addr>>8 or r[3]!=addr&0xff: bad.append(hex(addr)); mem+=b"\xee"*10; continue
    mem+=r[5:15]
os.close(fd)
open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"config-dump.bin"),"wb").write(mem)
print("failed reads:", bad or "none")
for i in range(0,len(mem),16): print(f"{i:04x}: "+" ".join(f"{b:02x}" for b in mem[i:i+16]))
def sc(a): v,p=mem[a],mem[a+1]; return v if (v+p)&0xff==0x55 else None
poll={8:125,4:250,2:500,1:1000,16:2000,32:4000,64:8000}
n=sc(2); act=sc(4)
print("\npolling:", poll.get(sc(0)), "Hz | stages:", n, "| active stage:", act, "| LOD raw:", sc(0x0a))
for s in range(n or 0):
    lo,du,fl,ck=mem[0x0c+s*4:0x10+s*4]
    ok=lo==du and (lo+du+fl+ck)&0xff==0x55
    print(f"  stage {s+1}: {((((fl>>2)&3)<<8)+lo+1)*50 if ok else 'bad'} DPI")
for k,a in [("debounce ms",0xa9),("motion sync",0xab),("sleep x10s",0xad),("angle snap",0xaf),("ripple",0xb1),("performance",0xb5)]: print(f"{k:12}: {sc(a)}")
