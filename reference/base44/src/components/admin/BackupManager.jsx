import React, { useState, useRef } from 'react';
import * as XLSX from 'xlsx';
import { base44 } from '@/api/base44Client';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Download, Upload, Loader2, CheckCircle2, AlertCircle } from 'lucide-react';

export default function BackupManager({ converts, congregations, onRefresh }) {
  const [importing, setImporting] = useState(false);
  const [importResult, setImportResult] = useState(null);
  const fileInputRef = useRef();

  const congregationMap = Object.fromEntries(congregations.map(c => [c.id, c.name]));
  const congregationNameToId = Object.fromEntries(congregations.map(c => [c.name, c.id]));

  const handleDownload = () => {
    const rows = converts.map(c => ({
      id_interno: c.id,
      nome: c.name,
      congregacao: congregationMap[c.congregation_id] || '',
      endereco: c.address || '',
      ponto_referencia: c.landmark || '',
      telefone: c.phone || '',
      idade: c.age || '',
      genero: c.gender === 'male' ? 'Masculino' : 'Feminino',
      data_conversao: c.conversion_date || '',
      tipo_culto: c.worship_type || '',
      visitas: c.visit_count || 0,
      em_discipulado: c.is_in_discipleship ? 'Sim' : 'Não',
      discipulado_concluido: c.is_discipleship_completed ? 'Sim' : 'Não',
      se_desviou: c.is_deviated ? 'Sim' : 'Não',
    }));

    const ws = XLSX.utils.json_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Convertidos');
    XLSX.writeFile(wb, `backup_convertidos_${new Date().toISOString().slice(0, 10)}.xlsx`);
  };

  const handleImport = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    setImporting(true);
    setImportResult(null);

    const data = await file.arrayBuffer();
    const wb = XLSX.read(data);
    const ws = wb.Sheets[wb.SheetNames[0]];
    const rows = XLSX.utils.sheet_to_json(ws);

    // IDs já existentes no app
    const existingIds = new Set(converts.map(c => c.id));

    let created = 0;
    let skipped = 0;

    for (const row of rows) {
      const internalId = row['id_interno'];

      // Se já existe no app, pular
      if (internalId && existingIds.has(internalId)) {
        skipped++;
        continue;
      }

      const congregationId = congregationNameToId[row['congregacao']] || null;

      await base44.entities.Convert.create({
        name: row['nome'] || '',
        congregation_id: congregationId,
        address: row['endereco'] || '',
        landmark: row['ponto_referencia'] || '',
        phone: row['telefone'] || '',
        age: row['idade'] ? Number(row['idade']) : undefined,
        gender: row['genero'] === 'Masculino' ? 'male' : 'female',
        conversion_date: row['data_conversao'] || '',
        worship_type: row['tipo_culto'] || '',
        visit_count: row['visitas'] ? Number(row['visitas']) : 0,
        was_visited_once: Number(row['visitas'] || 0) > 0,
        is_in_discipleship: row['em_discipulado'] === 'Sim',
        is_discipleship_completed: row['discipulado_concluido'] === 'Sim',
        is_deviated: row['se_desviou'] === 'Sim',
      });
      created++;
    }

    setImportResult({ created, skipped });
    setImporting(false);
    fileInputRef.current.value = '';
    if (created > 0) onRefresh();
  };

  return (
    <div className="space-y-4">
      {/* Download */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base flex items-center gap-2">
            <Download className="w-4 h-4" />
            Exportar Backup
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-sm text-slate-500">
            Baixe todos os convertidos em formato Excel (.xlsx). O arquivo inclui um <strong>ID interno</strong> único por registro, usado para evitar duplicatas na importação.
          </p>
          <Button onClick={handleDownload} className="bg-[#1e3a5f] hover:bg-[#1e3a5f]/90">
            <Download className="w-4 h-4 mr-2" />
            Baixar Backup ({converts.length} registros)
          </Button>
        </CardContent>
      </Card>

      {/* Import */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base flex items-center gap-2">
            <Upload className="w-4 h-4" />
            Importar Backup
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-sm text-slate-500">
            Importe um arquivo Excel exportado anteriormente. Registros com o mesmo <strong>ID interno</strong> já existentes no app serão ignorados (merge sem sobrescrever).
          </p>

          <input
            ref={fileInputRef}
            type="file"
            accept=".xlsx,.xls"
            onChange={handleImport}
            className="hidden"
          />
          <Button
            onClick={() => fileInputRef.current.click()}
            variant="outline"
            disabled={importing}
          >
            {importing ? (
              <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> Importando...</>
            ) : (
              <><Upload className="w-4 h-4 mr-2" /> Selecionar Arquivo</>
            )}
          </Button>

          {importResult && (
            <div className="rounded-lg border p-3 bg-slate-50 space-y-1">
              <div className="flex items-center gap-2 text-green-700 text-sm font-medium">
                <CheckCircle2 className="w-4 h-4" />
                {importResult.created} registro(s) importado(s) com sucesso
              </div>
              {importResult.skipped > 0 && (
                <div className="flex items-center gap-2 text-amber-600 text-sm">
                  <AlertCircle className="w-4 h-4" />
                  {importResult.skipped} registro(s) ignorado(s) (já existiam no app)
                </div>
              )}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}