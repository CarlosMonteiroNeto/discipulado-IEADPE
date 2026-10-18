"""Verify a production codec export with independent preinstalled openpyxl."""
import sys,zipfile,xml.etree.ElementTree as ET
import openpyxl
path=sys.argv[1]
w=openpyxl.load_workbook(path)
s=w['Convertidos']
expected=['id_interno','nome','congregacao','endereco','ponto_referencia','telefone','idade','genero','data_conversao','tipo_culto','visitas','em_discipulado','discipulado_concluido','se_desviou','data_ultima_visita','data_inicio_discipulado','visitado_ao_menos_uma_vez']
assert list(next(s.values))==expected
assert s.max_column==17 and s.max_row==2
assert w.defined_names['ieadpe_backup_version'].attr_text=='2'
assert all(c.data_type=='s' for row in s for c in row if c.value is not None)
assert s['B2'].value=='=1+1' and s['G2'].value=='0' and s['P2'].value=='2026-01-05'
assert s['F2'].value=='00123' and s['O2'].value=='2026-02-01'
with zipfile.ZipFile(path) as z:
    root=ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
    cells=root.findall('.//{http://schemas.openxmlformats.org/spreadsheetml/2006/main}c')
    assert len(cells)==34 and all(c.attrib['t']=='inlineStr' for c in cells)
    assert all('media/' not in n for n in z.namelist())
print('PASS: independent openpyxl and stdlib XML: exact17 headers; metadata2; all34 text cells; literal formula; age0; source ID, phone and dates; no binary photos.')
