import React, { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Badge } from "@/components/ui/badge";
import { Loader2, Search, Filter, Users, Pencil, Church } from "lucide-react";
import { toast } from "sonner";
import { format, differenceInDays } from 'date-fns';
import ConvertCard from '@/components/converts/ConvertCard';
import ConvertForm from '@/components/converts/ConvertForm';
import { sortCongregations, sortConvertsByCongregation } from '@/components/utils/sortCongregations';
import { resolveWeeklyReportIfNeeded } from '@/utils/weeklyReportUtils';

export default function Converts() {
  const queryClient = useQueryClient();
  const [searchTerm, setSearchTerm] = useState('');
  const [colorFilter, setColorFilter] = useState('all');
  const [congregationFilter, setCongregationFilter] = useState('all');
  const [editingConvert, setEditingConvert] = useState(null);
  const [showEditSheet, setShowEditSheet] = useState(false);
  const [currentUser, setCurrentUser] = useState(null);
  const [userAccess, setUserAccess] = useState(null);

  // Fetch current user
  useEffect(() => {
    const fetchUser = async () => {
      const user = await base44.auth.me();
      setCurrentUser(user);
    };
    fetchUser();
  }, []);

  const { data: rawCongregations = [] } = useQuery({
    queryKey: ['congregations'],
    queryFn: () => base44.entities.Congregation.list(),
  });

  const congregations = sortCongregations(rawCongregations);

  const { data: rawConverts = [], isLoading: loadingConverts } = useQuery({
    queryKey: ['converts'],
    queryFn: () => base44.entities.Convert.list('-created_date'),
  });

  const converts = sortConvertsByCongregation(rawConverts, congregations);

  const { data: accesses = [] } = useQuery({
    queryKey: ['user-accesses'],
    queryFn: () => base44.entities.UserAccess.list(),
  });

  // Get user access
  useEffect(() => {
    if (currentUser && accesses.length > 0) {
      const userAccessList = accesses.filter(a => a.user_email === currentUser.email);
      // Check if user has supervision role
      const hasSupervision = userAccessList.some(a => a.role === 'Membro da supervisão das campanhas');
      if (hasSupervision) {
        setUserAccess({ hasFullAccess: true });
      } else if (userAccessList.length > 0) {
        const congregationIds = userAccessList
          .filter(a => a.congregation_id)
          .map(a => a.congregation_id);
        setUserAccess({ hasFullAccess: false, congregationIds });
      } else {
        setUserAccess(null);
      }
    }
  }, [currentUser, accesses]);

  const updateMutation = useMutation({
    mutationFn: ({ id, data }) => base44.entities.Convert.update(id, data),
    onSuccess: (_, variables) => {
      const { data } = variables;
      if (data.conversion_date && data.congregation_id) {
        resolveWeeklyReportIfNeeded(data.congregation_id, data.conversion_date)
          .then(() => queryClient.invalidateQueries({ queryKey: ['weekly-reports'] }));
      }
      queryClient.invalidateQueries({ queryKey: ['converts'] });
      toast.success('Convertido atualizado!');
      setShowEditSheet(false);
      setEditingConvert(null);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => base44.entities.Convert.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['converts'] });
      toast.success('Convertido excluído!');
    },
  });

  // Calculate color for a convert
  const getConvertColor = (convert) => {
    const today = new Date();
    const lastVisit = new Date(convert.last_visit_date || convert.conversion_date);
    const daysSinceLastVisit = differenceInDays(today, lastVisit);

    let needsVisit = false;
    if (!convert.was_visited_once && daysSinceLastVisit >= 1) {
      needsVisit = true;
    } else if (convert.was_visited_once && !convert.is_in_discipleship && daysSinceLastVisit >= 7) {
      needsVisit = true;
    } else if (convert.is_in_discipleship && daysSinceLastVisit >= 30) {
      needsVisit = true;
    }

    if (needsVisit && !convert.is_in_discipleship) return 'red';
    if (!needsVisit && convert.is_in_discipleship) return 'green';
    return 'yellow';
  };

  // Filter converts
  const filteredConverts = converts.filter(convert => {
    // If not admin, check user access
    if (currentUser?.role !== 'admin' && userAccess) {
      if (!userAccess.hasFullAccess && !userAccess.congregationIds?.includes(convert.congregation_id)) {
        return false;
      }
    }
    
    // If user is not admin and has no access, hide all
    if (currentUser?.role !== 'admin' && !userAccess) {
      return false;
    }

    // Search filter
    if (searchTerm && !convert.name.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }

    // Color filter
    if (colorFilter !== 'all') {
      const color = getConvertColor(convert);
      if (color !== colorFilter) return false;
    }

    // Congregation filter
    if (congregationFilter !== 'all' && convert.congregation_id !== congregationFilter) {
      return false;
    }

    if (convert.is_discipleship_completed || convert.is_deviated) return false;
    return true;
  });

  const handleEdit = (convert) => {
    setEditingConvert(convert);
    setShowEditSheet(true);
  };

  const handleUpdate = (data) => {
    const dataWithCong = {
      ...data,
      congregation_id: data.congregation_id || editingConvert.congregation_id,
    };
    updateMutation.mutate({ id: editingConvert.id, data: dataWithCong });
  };

  const handleDelete = (id) => {
    deleteMutation.mutate(id);
  };

  const handleUpdateDiscipleship = (id, value) => {
    const today = format(new Date(), 'yyyy-MM-dd');
    const data = { is_in_discipleship: value };
    if (value) data.discipleship_start_date = today;
    updateMutation.mutate({ id, data });
    if (value) {
      const convert = converts.find(c => c.id === id);
      base44.entities.ConvertEvent.create({ convert_id: id, convert_name: convert?.name, congregation_id: convert?.congregation_id, event_type: 'discipleship_started', event_date: today, done_by_email: currentUser?.email });
    }
  };

  const handleMarkVisited = (id) => {
    const today = format(new Date(), 'yyyy-MM-dd');
    const convert = converts.find(c => c.id === id);
    const visitCount = (convert?.visit_count || 0) + 1;
    updateMutation.mutate({ id, data: { last_visit_date: today, was_visited_once: true, visit_count: visitCount } });
    base44.entities.ConvertEvent.create({ convert_id: id, convert_name: convert?.name, congregation_id: convert?.congregation_id, event_type: 'visit', event_date: today, done_by_email: currentUser?.email });
  };

  const handleMarkDiscipleshipCompleted = (id) => {
    const today = format(new Date(), 'yyyy-MM-dd');
    const convert = converts.find(c => c.id === id);
    updateMutation.mutate({ id, data: { is_discipleship_completed: true } });
    base44.entities.ConvertEvent.create({ convert_id: id, convert_name: convert?.name, congregation_id: convert?.congregation_id, event_type: 'discipleship_completed', event_date: today, done_by_email: currentUser?.email });
  };

  const handleMarkDeviated = (id) => {
    const today = format(new Date(), 'yyyy-MM-dd');
    const convert = converts.find(c => c.id === id);
    updateMutation.mutate({ id, data: { is_deviated: true } });
    base44.entities.ConvertEvent.create({ convert_id: id, convert_name: convert?.name, congregation_id: convert?.congregation_id, event_type: 'deviated', event_date: today, done_by_email: currentUser?.email });
  };

  const getCongregation = (id) => congregations.find(c => c.id === id);

  // Count by color
  const colorCounts = {
    red: filteredConverts.filter(c => getConvertColor(c) === 'red').length,
    yellow: filteredConverts.filter(c => getConvertColor(c) === 'yellow').length,
    green: filteredConverts.filter(c => getConvertColor(c) === 'green').length,
  };

  if (loadingConverts) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50 flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-[#1e3a5f]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50 p-4 pb-24">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-[#1e3a5f] flex items-center gap-2">
            <Users className="w-7 h-7" />
            Novos Convertidos
          </h1>
          <p className="text-slate-600 mt-1">
            {filteredConverts.length} convertido{filteredConverts.length !== 1 ? 's' : ''} encontrado{filteredConverts.length !== 1 ? 's' : ''}
          </p>
        </div>

        {/* Status Summary */}
        <div className="grid grid-cols-3 gap-3 mb-6">
          <div 
            className={`p-3 rounded-lg text-center cursor-pointer transition-all ${
              colorFilter === 'red' ? 'ring-2 ring-red-500' : ''
            } bg-red-100 border-2 border-red-400`}
            onClick={() => setColorFilter(colorFilter === 'red' ? 'all' : 'red')}
          >
            <div className="text-2xl font-bold text-red-700">{colorCounts.red}</div>
            <div className="text-xs text-red-600">Visita Urgente</div>
          </div>
          <div 
            className={`p-3 rounded-lg text-center cursor-pointer transition-all ${
              colorFilter === 'yellow' ? 'ring-2 ring-yellow-500' : ''
            } bg-yellow-100 border-2 border-yellow-400`}
            onClick={() => setColorFilter(colorFilter === 'yellow' ? 'all' : 'yellow')}
          >
            <div className="text-2xl font-bold text-yellow-700">{colorCounts.yellow}</div>
            <div className="text-xs text-yellow-600">Atenção</div>
          </div>
          <div 
            className={`p-3 rounded-lg text-center cursor-pointer transition-all ${
              colorFilter === 'green' ? 'ring-2 ring-green-500' : ''
            } bg-green-100 border-2 border-green-400`}
            onClick={() => setColorFilter(colorFilter === 'green' ? 'all' : 'green')}
          >
            <div className="text-2xl font-bold text-green-700">{colorCounts.green}</div>
            <div className="text-xs text-green-600">Em Dia</div>
          </div>
        </div>

        {/* Filters */}
        <div className="bg-white rounded-xl shadow-md p-4 mb-6 space-y-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <Input
              placeholder="Buscar por nome..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10"
            />
          </div>

          <div className="flex gap-3">
            <Select value={congregationFilter} onValueChange={setCongregationFilter}>
              <SelectTrigger className="flex-1">
                <Church className="w-4 h-4 mr-2 text-slate-400" />
                <SelectValue placeholder="Congregação" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Todas as congregações</SelectItem>
                {congregations.map((cong) => (
                  <SelectItem key={cong.id} value={cong.id}>
                    {cong.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            {(colorFilter !== 'all' || congregationFilter !== 'all') && (
              <Button
                variant="outline"
                onClick={() => {
                  setColorFilter('all');
                  setCongregationFilter('all');
                }}
                className="text-slate-500"
              >
                Limpar filtros
              </Button>
            )}
          </div>
        </div>

        {/* Convert Cards */}
        <div className="space-y-4">
          {filteredConverts.length === 0 ? (
            <div className="text-center py-12 bg-white rounded-xl shadow-md">
              <Users className="w-16 h-16 mx-auto text-slate-300 mb-4" />
              <p className="text-slate-500">Nenhum convertido encontrado</p>
            </div>
          ) : (
            filteredConverts.map((convert) => (
              <ConvertCard
                key={convert.id}
                convert={convert}
                congregation={getCongregation(convert.congregation_id)}
                onEdit={handleEdit}
                onDelete={handleDelete}
                onUpdateDiscipleship={handleUpdateDiscipleship}
                onMarkVisited={handleMarkVisited}
                onMarkDiscipleshipCompleted={handleMarkDiscipleshipCompleted}
                onMarkDeviated={handleMarkDeviated}
              />
            ))
          )}
        </div>
      </div>

      {/* Edit Sheet */}
      <Sheet open={showEditSheet} onOpenChange={setShowEditSheet}>
        <SheetContent side="bottom" className="h-[90vh] overflow-y-auto">
          <SheetHeader className="mb-4">
            <SheetTitle className="flex items-center gap-2">
              <Pencil className="w-5 h-5" />
              Editar Convertido
            </SheetTitle>
          </SheetHeader>
          {editingConvert && (
            <ConvertForm
              convert={editingConvert}
              congregations={congregations}
              onSave={handleUpdate}
              onCancel={() => setShowEditSheet(false)}
              isLoading={updateMutation.isPending}
            />
          )}
        </SheetContent>
      </Sheet>
    </div>
  );
}