"""Byte-patch the independent openpyxl fixture; no production serializer used."""
from pathlib import Path
import struct
root=Path(__file__).parent/'fixtures'
base=(root/'openpyxl-v2.xlsx').read_bytes()
u16=lambda b,p:struct.unpack_from('<H',b,p)[0]
u32=lambda b,p:struct.unpack_from('<I',b,p)[0]
def entries(data):
    end=len(data)-22; p=u32(data,end+16)
    result=[]
    for _ in range(u16(data,end+10)):
        n=46+u16(data,p+28)+u16(data,p+30)+u16(data,p+32)
        result.append((p,n,u32(data,p+42)));p+=n
    return result
for name,field in [('central-crc',16),('local-crc',14),('local-compressed-size',18),('local-expanded-size',22)]:
    b=bytearray(base);central,_,local=entries(b)[0]
    p=central+field if name=='central-crc' else local+field
    struct.pack_into('<I',b,p,u32(b,p)^1)
    (root/f'{name}.zip').write_bytes(b)
coherent=bytearray(base);central,_,local=entries(coherent)[0]
struct.pack_into('<I',coherent,central+16,u32(coherent,central+16)^1)
struct.pack_into('<I',coherent,local+14,u32(coherent,local+14)^1)
(root/'coherent-wrong-crc.zip').write_bytes(coherent)
def descriptors(data,signed):
    output=bytearray(); records=[]
    for p,n,local in entries(data):
        central=bytearray(data[p:p+n]); flags=u16(central,8)|8
        compressed=u32(central,20);expanded=u32(central,24);crc=u32(central,16)
        length=30+u16(data,local+26)+u16(data,local+28)+compressed
        member=bytearray(data[local:local+length])
        struct.pack_into('<H',member,6,flags);struct.pack_into('<III',member,14,0,0,0)
        struct.pack_into('<H',central,8,flags);struct.pack_into('<I',central,42,len(output))
        output.extend(member)
        if signed:output.extend(struct.pack('<I',0x08074b50))
        output.extend(struct.pack('<III',crc,compressed,expanded));records.append(central)
    start=len(output)
    for record in records:output.extend(record)
    output.extend(struct.pack('<IHHHHIIH',0x06054b50,0,0,len(records),len(records),len(output)-start,start,0))
    return output
for signed in [True,False]:
    label='signed' if signed else 'unsigned'
    b=descriptors(base,signed)
    (root/f'descriptor-{label}.xlsx').write_bytes(b)
    central,_,local=entries(b)[0]
    descriptor=local+30+u16(b,local+26)+u16(b,local+28)+u32(b,central+20)
    first=descriptor+(4 if signed else 0)
    for name,position in [('compressed-size',first+4),('expanded-size',first+8),('central-crc',central+16),('local-size',local+18)]:
        patched=bytearray(b);struct.pack_into('<I',patched,position,u32(patched,position)^1)
        (root/f'descriptor-{label}-{name}.zip').write_bytes(patched)
    coherent=bytearray(b)
    struct.pack_into('<I',coherent,central+16,u32(coherent,central+16)^1)
    struct.pack_into('<I',coherent,first,u32(coherent,first)^1)
    (root/f'descriptor-{label}-coherent-crc.zip').write_bytes(coherent)
print('Generated independent byte-patched metadata fixtures and valid signed/unsigned descriptor controls.')
