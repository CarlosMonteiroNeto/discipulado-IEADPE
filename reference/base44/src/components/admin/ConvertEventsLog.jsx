import React, { useState, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { base44 } from '@/api/base44Client';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Activity, Loader2, Download, ArrowUpDown, ArrowUp, ArrowDown, Search } from "lucide-react";
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import * as XLSX from 'xlsx';

const eventLabels = {
  visit: { label: 'Visita realizada', color: 'bg-blue-500' },
  discipleship_started: { label: 'Iniciou discipulado', color: 'bg-green-500' },
  discipleship_completed: { label: 'Concluiu discipulado', color: 'bg-emerald-600' },
  deviated: { label: 'Desviou-se', color: 'bg-red-500' },
};

export default function ConvertEventsLog({ congregations }) {
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [applied, setApplied] = useState(false);
  const [congregationFilter, setCongregationFilter] = useState('all');
  const [sortConfig, setSortConfig] = useState({ key: 'event_date', dir: 'desc' });

  const { data: events = [], isLoading } = useQuery({
    queryKey: ['convert-events'],
    queryFn: () => base44.entities.ConvertEvent.list('-created_date', 1000),
  });

  const getCongregationName = (id) => {
    if (!id) return '-';
    return congregations.find(c => c.id === id)?.name || 'Desconhecida';
  };

  const filteredEvents = useMemo(() => {
    if (!applied) return [];
    return events.filter(e => {
      const date = e.event_date;
      if (startDate && date < startDate) return false;
      if (endDate && date > endDate) return false;
      if (congregationFilter !== 'all' && e.congregation_id !== congregationFilter) return false;
      return true;
    });
  }, [events, applied, startDate, endDate, congregationFilter]);

  const sorted = useMemo(() => {
    if (!filteredEvents.length) return [];
    return [...filteredEvents].sort((a, b) => {
      let aVal = '', bVal = '';
      if (sortConfig.key === 'congregation') {
        aVal = getCongregationName(a.congregation_id);
        bVal = getCongregationName(b.congregation_id);
      } else if (sortConfig.key === 'event_type') {
        aVal = eventLabels[a.event_type]?.label || a.event_type;
        bVal = eventLabels[b.event_type]?.label || b.event_type;
      } else {
        aVal = a[sortConfig.key] || '';
        bVal = b[sortConfig.key] || '';
      }
      const cmp = aVal.toString().localeCompare(bVal.toString(), 'pt-BR');
      return sortConfig.dir === 'asc' ? cmp : -cmp;
    });
  }, [filteredEvents, sortConfig]);

  const handleSort = (key) => {
    setSortConfig(prev => prev.key === key
      ? { key, dir: prev.dir === 'asc' ? 'desc' : 'asc' }
      : { key, dir: 'asc' }
    );
  };

  const SortIcon = ({ col }) => {
    if (sortConfig.key !== col) return <ArrowUpDown className="w-3 h-3 inline ml-1 opacity-40" />;
    return sortConfig.dir === 'asc'
      ? <ArrowUp className="w-3 h-3 inline ml-1" />
      : <ArrowDown className="w-3 h-3 inline ml-1" />;
  };

  const handleExport = () => {
    const rows = sorted.map(e => ({
      'Convertido': e.convert_name || '-',
      'Congregação': getCongregationName(e.congregation_id),
      'Evento': eventLabels[e.event_type]?.label || e.event_type,
      'Data do Evento': e.event_date ? format(new Date(e.event_date + 'T12:00:00'), 'dd/MM/yyyy') : '-',
      'Registrado por': e.done_by_email || '-',
    }));
    const ws = XLSX.utils.json_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Eventos');
    XLSX.writeFile(wb, `eventos_${startDate}_${endDate}.xlsx`);
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Activity className="w-5 h-5" />
          Registro de Eventos
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Filtros */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          <div className="space-y-1">
            <Label className="text-xs">Data inicial</Label>
            <Input type="date" value={startDate} onChange={e => { setStartDate(e.target.value); setApplied(false); }} />
          </div>
          <div className="space-y-1">
            <Label className="text-xs">Data final</Label>
            <Input type="date" value={endDate} onChange={e => { setEndDate(e.target.value); setApplied(false); }} />
          </div>
          <div className="space-y-1">
            <Label className="text-xs">Congregação</Label>
            <Select value={congregationFilter} onValueChange={v => { setCongregationFilter(v); setApplied(false); }}>
              <SelectTrigger>
                <SelectValue placeholder="Todas" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Todas</SelectItem>
                {congregations.map(c => (
                  <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex items-end">
            <Button
              className="w-full bg-[#1e3a5f] hover:bg-[#2563eb]"
              onClick={() => setApplied(true)}
              disabled={!startDate || !endDate}
            >
              <Search className="w-4 h-4 mr-2" />
              Buscar
            </Button>
          </div>
        </div>

        {/* Loading */}
        {isLoading && (
          <div className="flex justify-center py-8">
            <Loader2 className="w-6 h-6 animate-spin text-[#1e3a5f]" />
          </div>
        )}

        {/* Resultado */}
        {applied && !isLoading && (
          <>
            <div className="flex items-center justify-between">
              <span className="text-sm text-slate-500">{sorted.length} evento(s) encontrado(s)</span>
              {sorted.length > 0 && (
                <Button variant="outline" size="sm" onClick={handleExport}>
                  <Download className="w-4 h-4 mr-2" />
                  Exportar XLSX
                </Button>
              )}
            </div>

            {sorted.length === 0 ? (
              <p className="text-center text-slate-500 py-6">Nenhum evento no período selecionado.</p>
            ) : (
              <div className="overflow-x-auto rounded-lg border">
                <table className="w-full text-sm">
                  <thead className="bg-slate-100 text-slate-700">
                    <tr>
                      {[
                        { key: 'convert_name', label: 'Convertido' },
                        { key: 'congregation', label: 'Congregação' },
                        { key: 'event_type', label: 'Evento' },
                        { key: 'event_date', label: 'Data' },
                        { key: 'done_by_email', label: 'Registrado por' },
                      ].map(col => (
                        <th
                          key={col.key}
                          className="px-3 py-2 text-left cursor-pointer hover:bg-slate-200 select-none whitespace-nowrap"
                          onClick={() => handleSort(col.key)}
                        >
                          {col.label}<SortIcon col={col.key} />
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {sorted.map((event, i) => {
                      const info = eventLabels[event.event_type] || { label: event.event_type, color: 'bg-slate-500' };
                      return (
                        <tr key={event.id} className={i % 2 === 0 ? 'bg-white' : 'bg-slate-50'}>
                          <td className="px-3 py-2 font-medium">{event.convert_name || '-'}</td>
                          <td className="px-3 py-2">{getCongregationName(event.congregation_id)}</td>
                          <td className="px-3 py-2">
                            <Badge className={`${info.color} text-white text-xs`}>{info.label}</Badge>
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap">
                            {event.event_date
                              ? format(new Date(event.event_date + 'T12:00:00'), 'dd/MM/yyyy', { locale: ptBR })
                              : '-'}
                          </td>
                          <td className="px-3 py-2 text-slate-500 text-xs">{event.done_by_email || '-'}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </>
        )}

        {!applied && !isLoading && (
          <p className="text-center text-slate-400 py-6">Selecione um intervalo de datas e clique em Buscar.</p>
        )}
      </CardContent>
    </Card>
  );
}