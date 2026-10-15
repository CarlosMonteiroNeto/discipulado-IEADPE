import React, { useState } from 'react';
import { base44 } from '@/api/base44Client';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Card, CardContent } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Church, CheckCircle2, AlertCircle, Clock } from "lucide-react";
import { format } from 'date-fns';
import { sortCongregations } from '@/components/utils/sortCongregations';

/**
 * Returns the reporting period:
 * - weekStartStr: Monday of the week being reported (YYYY-MM-DD)
 * - weekEndStr:   Sunday of that week (YYYY-MM-DD)
 * - isPastThreshold: true if it's past Sunday 20:00 of that week
 */
function getReportingPeriod() {
  const now = new Date();
  const dayOfWeek = now.getDay(); // 0 = Sun

  // Find the most recent Sunday (could be today)
  const lastSunday = new Date(now);
  if (dayOfWeek !== 0) {
    lastSunday.setDate(now.getDate() - dayOfWeek);
  }
  lastSunday.setHours(0, 0, 0, 0);

  // Threshold = that Sunday at 20:00
  const threshold = new Date(lastSunday);
  threshold.setHours(20, 0, 0, 0);

  const isPastThreshold = now >= threshold;

  // Week start = Monday (6 days before that Sunday)
  const weekStart = new Date(lastSunday);
  weekStart.setDate(lastSunday.getDate() - 6);
  weekStart.setHours(0, 0, 0, 0);

  const weekStartStr = format(weekStart, 'yyyy-MM-dd');
  const weekEndStr = format(lastSunday, 'yyyy-MM-dd');

  return { isPastThreshold, weekStartStr, weekEndStr };
}

export default function WeeklyConversionReport({ currentUser, converts, congregations, accesses }) {
  const [confirmCongId, setConfirmCongId] = useState(null);
  const queryClient = useQueryClient();

  const { isPastThreshold, weekStartStr, weekEndStr } = getReportingPeriod();

  const { data: weeklyReports = [] } = useQuery({
    queryKey: ['weekly-reports', weekStartStr],
    queryFn: () => base44.entities.WeeklyReport.filter({ week_start: weekStartStr }),
    enabled: isPastThreshold,
  });

  if (!isPastThreshold) return null;

  const userAccessList = accesses.filter(a => a.user_email === currentUser?.email);
  const hasSupervision =
    currentUser?.role === 'admin' ||
    userAccessList.some(a => a.role === 'Membro da supervisão das campanhas');
  const userCongregationIds = userAccessList
    .filter(a => a.congregation_id)
    .map(a => a.congregation_id);

  // Congregations that had converts this week
  const congregationsWithConverts = new Set(
    converts
      .filter(c => c.conversion_date >= weekStartStr && c.conversion_date <= weekEndStr)
      .map(c => c.congregation_id)
  );

  const sortedCongregations = sortCongregations(congregations);
  const getReport = (congId) => weeklyReports.find(r => r.congregation_id === congId);

  const handleConfirm = async () => {
    await base44.entities.WeeklyReport.create({
      congregation_id: confirmCongId,
      week_start: weekStartStr,
      confirmed_by_email: currentUser.email,
      confirmed_by_name: currentUser.full_name || currentUser.email,
    });
    queryClient.invalidateQueries({ queryKey: ['weekly-reports', weekStartStr] });
    setConfirmCongId(null);
  };

  // ── SUPERVISÃO: lista completa ────────────────────────────────────────────
  if (hasSupervision) {
    const congsSemConversoes = sortedCongregations.filter(
      c => !congregationsWithConverts.has(c.id)
    );
    if (congsSemConversoes.length === 0) return null;

    return (
      <div className="mb-8">
        <h2 className="text-lg font-bold text-[#1e3a5f] mb-4 flex items-center gap-2">
          <AlertCircle className="w-5 h-5 text-orange-500" />
          Sem Conversões na Última Semana
        </h2>
        <Card>
          <CardContent className="p-4 divide-y">
            {congsSemConversoes.map(cong => {
              const report = getReport(cong.id);
              return (
                <div key={cong.id} className="flex items-center justify-between py-2">
                  <div className="flex items-center gap-2">
                    <Church className="w-4 h-4 text-slate-400" />
                    <span className="text-sm font-medium text-slate-700">{cong.name}</span>
                  </div>
                  {report ? (
                    <Badge className="bg-blue-600 text-xs gap-1">
                      <CheckCircle2 className="w-3 h-3" />
                      Confirmado
                    </Badge>
                  ) : (
                    <Badge variant="outline" className="border-orange-400 text-orange-600 text-xs gap-1">
                      <Clock className="w-3 h-3" />
                      Aguardando
                    </Badge>
                  )}
                </div>
              );
            })}
          </CardContent>
        </Card>
      </div>
    );
  }

  // ── CONGREGAÇÃO: checkbox para confirmar sem conversões ───────────────────
  const myCongsSemConversoes = userCongregationIds.filter(
    id => !congregationsWithConverts.has(id)
  );

  if (myCongsSemConversoes.length === 0) return null;

  return (
    <>
      {myCongsSemConversoes.map(congId => {
        const cong = congregations.find(c => c.id === congId);
        if (!cong) return null;
        const report = getReport(congId);
        return (
          <div key={congId} className="mb-4">
            <Card className="border-orange-200 bg-orange-50">
              <CardContent className="p-4">
                {report ? (
                  <div className="flex items-center gap-3">
                    <CheckCircle2 className="w-5 h-5 text-green-600 shrink-0" />
                    <div>
                      <p className="font-semibold text-green-800 text-sm">Relatório confirmado</p>
                      <p className="text-xs text-green-700">
                        Você confirmou que não houve conversões em <strong>{cong.name}</strong> na última semana.
                      </p>
                    </div>
                  </div>
                ) : (
                  <div
                    className="flex items-start gap-3 cursor-pointer"
                    onClick={() => setConfirmCongId(congId)}
                  >
                    <Checkbox
                      id={`weekly-${congId}`}
                      checked={false}
                      onCheckedChange={() => setConfirmCongId(congId)}
                      className="mt-0.5"
                    />
                    <label htmlFor={`weekly-${congId}`} className="cursor-pointer">
                      <p className="font-semibold text-orange-800 text-sm">
                        Não houve conversões em <strong>{cong.name}</strong> na última semana
                      </p>
                      <p className="text-xs text-orange-700 mt-0.5">
                        Marque esta caixa para confirmar o relatório semanal.
                      </p>
                    </label>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        );
      })}

      <AlertDialog open={!!confirmCongId} onOpenChange={(open) => !open && setConfirmCongId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmar relatório semanal</AlertDialogTitle>
            <AlertDialogDescription>
              Você confirma que não houve conversões em{' '}
              <strong>{congregations.find(c => c.id === confirmCongId)?.name}</strong>{' '}
              na última semana ({weekStartStr} a {weekEndStr})?
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={handleConfirm}>Confirmar</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}