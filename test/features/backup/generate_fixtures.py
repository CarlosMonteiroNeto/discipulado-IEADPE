"""Synthetic independent stdlib ZIP and openpyxl fixtures. No app writer used."""
from pathlib import Path
import zipfile, struct
import openpyxl
from openpyxl.workbook.defined_name import DefinedName
root=Path(__file__).parent / 'fixtures'
headers=['id_interno','nome','congregacao','endereco','ponto_referencia','telefone','idade','genero','data_conversao','tipo_culto','visitas','em_discipulado','discipulado_concluido','se_desviou','data_ultima_visita','data_inicio_discipulado','visitado_ao_menos_uma_vez']
wb=openpyxl.Workbook();ws=wb.active;ws.title='Convertidos'
ws.append(headers);ws.append(['old-source-key','Synthetic','Central','','Reference','00123',0,'Feminino','2026-01-01','Culto',1,'Sim','Não','Não','2026-02-01','2026-01-05','Sim'])
wb.defined_names.add(DefinedName('ieadpe_backup_version',attr_text='2'))
wb.save(root/'openpyxl-v2.xlsx')
with zipfile.ZipFile(root/'expanded-bomb.zip','w',compression=zipfile.ZIP_DEFLATED) as z:
    with z.open('bomb.xml','w') as f:
        for _ in range(51): f.write(b'0'*(1024*1024))
data=bytearray((root/'expanded-bomb.zip').read_bytes())
p=data.index(b'PK\x01\x02');struct.pack_into('<I',data,p+24,1)
struct.pack_into('<I',data,22,1)  # Coherent local/central sizes; actual output is 51MiB.
(root/'understated-bomb.zip').write_bytes(data)
# central-directory size alone must be rejected before missing local bytes.
data=bytearray((root/'expanded-bomb.zip').read_bytes());p=data.index(b'PK\x01\x02');struct.pack_into('<I',data,p+24,0xffffffff)
(root/'declared-bomb.zip').write_bytes(data)
print('Generated four synthetic independent fixtures.')
with zipfile.ZipFile(root/'openpyxl-v2.xlsx') as source:
    with zipfile.ZipFile(root/'duplicate-entry.zip','w',compression=zipfile.ZIP_DEFLATED) as z:
        for item in source.infolist(): z.writestr(item.filename,source.read(item))
        z.writestr('xl/workbook.xml',source.read('xl/workbook.xml'))
with zipfile.ZipFile(root/'aggregate-bomb.zip','w',compression=zipfile.ZIP_DEFLATED) as z:
    for name in ['a.xml','b.xml']:
        with z.open(name,'w') as f:
            for _ in range(26): f.write(b'0'*(1024*1024))
