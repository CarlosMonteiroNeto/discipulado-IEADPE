import React, { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { createPageUrl } from '@/utils';
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { 
  Users, 
  UserPlus, 
  Settings, 
  Church,
  TrendingUp,
  AlertTriangle,
  CheckCircle,
  Loader2
} from "lucide-react";
import { differenceInDays, format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { sortCongregations } from '@/components/utils/sortCongregations';
import WeeklyConversionReport from '@/components/home/WeeklyConversionReport';

export default function Home() {
  const [currentUser, setCurrentUser] = useState(null);

  useEffect(() => {
    const fetchUser = async () => {
      const user = await base44.auth.me();
      setCurrentUser(user);
    };
    fetchUser();
  }, []);

  const { data: converts = [], isLoading: loadingConverts } = useQuery({
    queryKey: ['converts'],
    queryFn: () => base44.entities.Convert.list('-created_date'),
  });

  const { data: rawCongregations = [] } = useQuery({
    queryKey: ['congregations'],
    queryFn: () => base44.entities.Congregation.list(),
  });

  const congregations = sortCongregations(rawCongregations);

  const { data: accesses = [] } = useQuery({
    queryKey: ['user-accesses'],
    queryFn: () => base44.entities.UserAccess.list(),
  });

  // Filter converts based on user access
  const userAccessList = accesses.filter(a => a.user_email === currentUser?.email);
  const hasSupervision = userAccessList.some(a => a.role === 'Membro da supervisão das campanhas');
  const congregationIds = userAccessList
    .filter(a => a.congregation_id)
    .map(a => a.congregation_id);
  
  const accessibleConverts = currentUser?.role === 'admin' || hasSupervision
    ? converts 
    : converts.filter(c => congregationIds.includes(c.congregation_id));

  // Calculate stats
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

  const urgentVisits = accessibleConverts.filter(c => getConvertColor(c) === 'red').length;
  const inDiscipleship = accessibleConverts.filter(c => c.is_in_discipleship).length;
  const total = accessibleConverts.length;

  // Recent converts (last 7 days)
  const recentConverts = accessibleConverts
    .filter(c => {
      const convDate = new Date(c.conversion_date);
      return differenceInDays(new Date(), convDate) <= 7;
    })
    .slice(0, 5);

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
        {/* Welcome Header */}
        <div className="mb-8">
          <div className="bg-gradient-to-r from-[#1e3a5f] to-[#2563eb] rounded-2xl p-6 text-white shadow-xl">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-12 h-12 bg-white/20 rounded-full flex items-center justify-center">
                <Church className="w-6 h-6" />
              </div>
              <div>
                <h1 className="text-2xl font-bold">IEADPE</h1>
                <p className="text-blue-100 text-sm">Gestão de Novos Convertidos</p>
              </div>
            </div>
            <p className="text-blue-100 mt-4">
              Olá, <span className="font-semibold text-white">{currentUser?.full_name || 'Visitante'}</span>!
            </p>
          </div>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-3 gap-3 mb-8">
          <Card className="bg-white shadow-md hover:shadow-lg transition-shadow">
            <CardContent className="p-4 text-center">
              <Users className="w-8 h-8 mx-auto text-[#1e3a5f] mb-2" />
              <div className="text-2xl font-bold text-[#1e3a5f]">{total}</div>
              <div className="text-xs text-slate-500">Total</div>
            </CardContent>
          </Card>
          <Card className="bg-red-50 border-red-200 shadow-md hover:shadow-lg transition-shadow">
            <CardContent className="p-4 text-center">
              <AlertTriangle className="w-8 h-8 mx-auto text-red-600 mb-2" />
              <div className="text-2xl font-bold text-red-700">{urgentVisits}</div>
              <div className="text-xs text-red-600">Visitas Urgentes</div>
            </CardContent>
          </Card>
          <Card className="bg-green-50 border-green-200 shadow-md hover:shadow-lg transition-shadow">
            <CardContent className="p-4 text-center">
              <CheckCircle className="w-8 h-8 mx-auto text-green-600 mb-2" />
              <div className="text-2xl font-bold text-green-700">{inDiscipleship}</div>
              <div className="text-xs text-green-600">Em Discipulado</div>
            </CardContent>
          </Card>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-2 gap-4 mb-8">
          <Link to={createPageUrl('Register')}>
            <Card className="bg-gradient-to-br from-[#1e3a5f] to-[#2563eb] text-white shadow-lg hover:shadow-xl transition-all hover:scale-[1.02] cursor-pointer h-full">
              <CardContent className="p-6 flex flex-col items-center justify-center text-center">
                <UserPlus className="w-12 h-12 mb-3" />
                <h3 className="font-bold text-lg">Novo Cadastro</h3>
                <p className="text-blue-100 text-sm mt-1">Registrar convertido</p>
              </CardContent>
            </Card>
          </Link>
          <Link to={createPageUrl('Converts')}>
            <Card className="bg-white border-2 border-[#1e3a5f] shadow-lg hover:shadow-xl transition-all hover:scale-[1.02] cursor-pointer h-full">
              <CardContent className="p-6 flex flex-col items-center justify-center text-center">
                <Users className="w-12 h-12 mb-3 text-[#1e3a5f]" />
                <h3 className="font-bold text-lg text-[#1e3a5f]">Ver Convertidos</h3>
                <p className="text-slate-500 text-sm mt-1">Gerenciar cadastros</p>
              </CardContent>
            </Card>
          </Link>
        </div>

        {/* Weekly Conversion Report */}
        {currentUser && (
          <WeeklyConversionReport
            currentUser={currentUser}
            converts={converts}
            congregations={congregations}
            accesses={accesses}
          />
        )}

        {/* Recent Converts */}
        {recentConverts.length > 0 && (
          <div className="mb-8">
            <h2 className="text-lg font-bold text-[#1e3a5f] mb-4 flex items-center gap-2">
              <TrendingUp className="w-5 h-5" />
              Convertidos Recentes
            </h2>
            <div className="space-y-2">
              {recentConverts.map((convert) => (
                <Card key={convert.id} className="bg-white shadow-sm hover:shadow-md transition-shadow">
                  <CardContent className="p-4 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      {convert.photo_url ? (
                        <img
                          src={convert.photo_url}
                          alt={convert.name}
                          className="w-10 h-10 rounded-full object-cover"
                        />
                      ) : (
                        <div className="w-10 h-10 rounded-full bg-slate-200 flex items-center justify-center">
                          <Users className="w-5 h-5 text-slate-400" />
                        </div>
                      )}
                      <div>
                        <p className="font-medium text-slate-800">{convert.name}</p>
                        <p className="text-xs text-slate-500">
                          {format(new Date(convert.conversion_date), "dd 'de' MMMM", { locale: ptBR })}
                        </p>
                      </div>
                    </div>
                    <div className={`w-3 h-3 rounded-full ${
                      getConvertColor(convert) === 'red' ? 'bg-red-500' :
                      getConvertColor(convert) === 'green' ? 'bg-green-500' : 'bg-yellow-500'
                    }`} />
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        )}

        {/* Admin Link */}
        {currentUser?.role === 'admin' && (
          <Link to={createPageUrl('Admin')}>
            <Card className="bg-slate-100 border-slate-200 shadow-md hover:shadow-lg transition-all hover:scale-[1.01] cursor-pointer">
              <CardContent className="p-4 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Settings className="w-8 h-8 text-slate-600" />
                  <div>
                    <h3 className="font-bold text-slate-700">Administração</h3>
                    <p className="text-xs text-slate-500">Congregações e acessos</p>
                  </div>
                </div>
                <div className="text-slate-400">→</div>
              </CardContent>
            </Card>
          </Link>
        )}
      </div>
    </div>
  );
}