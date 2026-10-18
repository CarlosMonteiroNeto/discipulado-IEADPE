import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Download, FileSpreadsheet } from 'lucide-react';
import * as XLSX from 'xlsx';
import { format } from 'date-fns';

const COLORS = [
  '#1e3a5f','#2563eb','#10b981','#f59e0b','#ef4444','#8b5cf6',
  '#06b6d4','#ec4899','#84cc16','#f97316','#6366f1','#14b8a6',
  '#a855f7','#fb923c','#22c55e','#e11d48',
];

export default function ConversionReport({ converts }) {
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  const filteredConverts = converts.filter(c => {
    if (!c.conversion_date) return false;
    if (startDate && c.conversion_date < startDate) return false;
    if (endDate && c.conversion_date > endDate) return false;
    return true;
  });

  // Count by worship_type
  const countByType = {};
  filteredConverts.forEach(c => {
    const type = c.worship_type || 'Não informado';
    countByType[type] = (countByType[type] || 0) + 1;
  });

  const chartData = Object.entries(countByType)
    .map(([name, value]) => ({ name, value }))
    .sort((a, b) => b.value - a.value);

  const handleDownload = () => {
    if (chartData.length === 0) return;

    const rows = chartData.map(({ name, value }) => ({
      'Tipo de Culto': name,
      'Conversões': value,
    }));

    const ws = XLSX.utils.json_to_sheet(rows);
    ws['!cols'] = [{ wch: 50 }, { wch: 15 }];

    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Conversões por Culto');

    const fileName = `relatorio_conversoes_${startDate || 'inicio'}_${endDate || 'fim'}.xlsx`;
    XLSX.writeFile(wb, fileName);
  };

  return (
    <div className="space-y-4">
      {/* Period selector */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base flex items-center gap-2">
            <FileSpreadsheet className="w-5 h-5 text-[#1e3a5f]" />
            Relatório por Tipo de Culto
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <Label htmlFor="start-date">Data Inicial</Label>
              <Input
                id="start-date"
                type="date"
                value={startDate}
                onChange={e => setStartDate(e.target.value)}
              />
            </div>
            <div className="space-y-1">
              <Label htmlFor="end-date">Data Final</Label>
              <Input
                id="end-date"
                type="date"
                value={endDate}
                onChange={e => setEndDate(e.target.value)}
              />
            </div>
          </div>

          <div className="flex items-center justify-between">
            <p className="text-sm text-slate-500">
              {filteredConverts.length} conversões no período
            </p>
            <Button
              onClick={handleDownload}
              disabled={chartData.length === 0}
              className="bg-[#1e3a5f] hover:bg-[#2563eb]"
              size="sm"
            >
              <Download className="w-4 h-4 mr-2" />
              Baixar XLSX
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Chart */}
      {chartData.length > 0 && (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Distribuição por Tipo de Culto</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={320}>
              <PieChart>
                <Pie
                  data={chartData}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={110}
                  label={({ name, value }) => `${value}`}
                  labelLine={false}
                >
                  {chartData.map((_, i) => (
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(value, name) => [value, name]} />
                <Legend
                  layout="vertical"
                  align="right"
                  verticalAlign="middle"
                  formatter={(value) => (
                    <span className="text-xs text-slate-700">{value}</span>
                  )}
                />
              </PieChart>
            </ResponsiveContainer>

            {/* Table */}
            <div className="mt-4 divide-y border rounded-lg overflow-hidden">
              {chartData.map(({ name, value }, i) => (
                <div key={name} className="flex items-center justify-between px-3 py-2 text-sm">
                  <div className="flex items-center gap-2">
                    <div
                      className="w-3 h-3 rounded-full flex-shrink-0"
                      style={{ backgroundColor: COLORS[i % COLORS.length] }}
                    />
                    <span className="text-slate-700">{name}</span>
                  </div>
                  <span className="font-semibold text-slate-800">{value}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {chartData.length === 0 && (startDate || endDate) && (
        <Card className="bg-slate-50">
          <CardContent className="py-8 text-center text-slate-500 text-sm">
            Nenhuma conversão encontrada no período selecionado.
          </CardContent>
        </Card>
      )}
    </div>
  );
}