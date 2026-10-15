import React, { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Loader2, Settings, Church, Users, BarChart3, HardDrive, Activity } from "lucide-react";
import ConvertEventsLog from '@/components/admin/ConvertEventsLog';
import CongregationManager from '@/components/admin/CongregationManager';
import UserAccessManager from '@/components/admin/UserAccessManager';
import ConversionReport from '@/components/admin/ConversionReport';
import BackupManager from '@/components/admin/BackupManager';
import { sortCongregations } from '@/components/utils/sortCongregations';

export default function Admin() {
  const queryClient = useQueryClient();
  const [currentUser, setCurrentUser] = useState(null);

  useEffect(() => {
    const fetchUser = async () => {
      const user = await base44.auth.me();
      setCurrentUser(user);
    };
    fetchUser();
  }, []);

  const { data: rawCongregations = [], isLoading: loadingCongregations } = useQuery({
    queryKey: ['congregations'],
    queryFn: () => base44.entities.Congregation.list(),
  });

  const congregations = sortCongregations(rawCongregations);

  const { data: accesses = [], isLoading: loadingAccesses } = useQuery({
    queryKey: ['user-accesses'],
    queryFn: () => base44.entities.UserAccess.list(),
  });

  const { data: converts = [], isLoading: loadingConverts } = useQuery({
    queryKey: ['converts'],
    queryFn: () => base44.entities.Convert.list(),
  });

  const handleRefresh = () => {
    queryClient.invalidateQueries({ queryKey: ['congregations'] });
    queryClient.invalidateQueries({ queryKey: ['user-accesses'] });
    queryClient.invalidateQueries({ queryKey: ['converts'] });
  };

  // Stats
  const totalConverts = converts.length;
  const inDiscipleship = converts.filter(c => c.is_in_discipleship).length;
  const visitedOnce = converts.filter(c => c.was_visited_once).length;

  const isSupervision = accesses.some(
    a => a.user_email === currentUser?.email && a.role === 'Membro da supervisão das campanhas'
  );
  const hasAdminAccess = currentUser?.role === 'admin' || isSupervision;

  if (currentUser && !hasAdminAccess) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50 flex items-center justify-center p-4">
        <Card className="max-w-md w-full">
          <CardContent className="pt-6 text-center">
            <Settings className="w-16 h-16 mx-auto text-slate-300 mb-4" />
            <h2 className="text-xl font-bold text-slate-700 mb-2">Acesso Restrito</h2>
            <p className="text-slate-500">
              Esta área é restrita a administradores.
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (loadingCongregations || loadingAccesses || loadingConverts) {
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
            <Settings className="w-7 h-7" />
            Administração
          </h1>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-3 gap-3 mb-6">
          <Card className="bg-gradient-to-br from-[#1e3a5f] to-[#2563eb] text-white">
            <CardContent className="p-4 text-center">
              <div className="text-3xl font-bold">{totalConverts}</div>
              <div className="text-xs opacity-80">Total de Convertidos</div>
            </CardContent>
          </Card>
          <Card className="bg-gradient-to-br from-green-600 to-green-500 text-white">
            <CardContent className="p-4 text-center">
              <div className="text-3xl font-bold">{inDiscipleship}</div>
              <div className="text-xs opacity-80">Em Discipulado</div>
            </CardContent>
          </Card>
          <Card className="bg-gradient-to-br from-blue-600 to-blue-500 text-white">
            <CardContent className="p-4 text-center">
              <div className="text-3xl font-bold">{visitedOnce}</div>
              <div className="text-xs opacity-80">Já Visitados</div>
            </CardContent>
          </Card>
        </div>

        {/* Tabs */}
        <Tabs defaultValue="congregations" className="space-y-4">
          <TabsList className="grid grid-cols-5 w-full">
            <TabsTrigger value="congregations" className="flex items-center gap-2">
              <Church className="w-4 h-4" />
              Congregações
            </TabsTrigger>
            <TabsTrigger value="access" className="flex items-center gap-2">
              <Users className="w-4 h-4" />
              Acessos
            </TabsTrigger>
            <TabsTrigger value="report" className="flex items-center gap-2">
              <BarChart3 className="w-4 h-4" />
              Relatório
            </TabsTrigger>
            <TabsTrigger value="events" className="flex items-center gap-2">
              <Activity className="w-4 h-4" />
              Eventos
            </TabsTrigger>
            <TabsTrigger value="backup" className="flex items-center gap-2">
              <HardDrive className="w-4 h-4" />
              Backup
            </TabsTrigger>
          </TabsList>

          <TabsContent value="congregations">
            <CongregationManager
              congregations={congregations}
              onRefresh={handleRefresh}
            />
          </TabsContent>

          <TabsContent value="access">
            <UserAccessManager
              accesses={accesses}
              congregations={congregations}
              onRefresh={handleRefresh}
            />
          </TabsContent>

          <TabsContent value="report">
            <ConversionReport converts={converts} />
          </TabsContent>

          <TabsContent value="events">
            <ConvertEventsLog congregations={congregations} />
          </TabsContent>

          <TabsContent value="backup">
            <BackupManager
              converts={converts}
              congregations={congregations}
              onRefresh={handleRefresh}
            />
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}