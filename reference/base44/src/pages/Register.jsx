import React, { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { toast } from "sonner";
import { UserPlus, Loader2 } from "lucide-react";
import ConvertForm from '@/components/converts/ConvertForm';
import { sortCongregations } from '@/components/utils/sortCongregations';
import { resolveWeeklyReportIfNeeded } from '@/utils/weeklyReportUtils';

export default function Register() {
  const queryClient = useQueryClient();

  const { data: rawCongregations = [], isLoading: loadingCongregations } = useQuery({
    queryKey: ['congregations'],
    queryFn: () => base44.entities.Congregation.list(),
  });

  const congregations = sortCongregations(rawCongregations);

  const createMutation = useMutation({
    mutationFn: (data) => base44.entities.Convert.create(data),
    onSuccess: (created, variables) => {
      resolveWeeklyReportIfNeeded(variables.congregation_id, variables.conversion_date)
        .then(() => queryClient.invalidateQueries({ queryKey: ['weekly-reports'] }));
      queryClient.invalidateQueries({ queryKey: ['converts'] });
      toast.success('Novo convertido cadastrado com sucesso!');
      window.location.reload();
    },
  });

  const handleSave = (data) => {
    createMutation.mutate(data);
  };

  const handleCancel = () => {
    window.history.back();
  };

  if (loadingCongregations) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50 flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-[#1e3a5f]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50 p-4 pb-24">
      <div className="max-w-lg mx-auto">
        <Card className="shadow-xl border-t-4 border-t-[#1e3a5f]">
          <CardHeader className="bg-gradient-to-r from-[#1e3a5f] to-[#2563eb] text-white rounded-t-lg">
            <CardTitle className="flex items-center gap-2">
              <UserPlus className="w-6 h-6" />
              Cadastrar Novo Convertido
            </CardTitle>
          </CardHeader>
          <CardContent className="pt-6">
            <ConvertForm
              congregations={congregations}
              onSave={handleSave}
              onCancel={handleCancel}
              isLoading={createMutation.isPending}
            />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}