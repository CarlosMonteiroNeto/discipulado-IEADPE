import React from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { base44 } from '@/api/base44Client';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { MessageSquare, Loader2, Check } from "lucide-react";
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const statusConfig = {
  pending: { label: 'Novo', color: 'bg-orange-500' },
  read: { label: 'Lido', color: 'bg-blue-500' },
  resolved: { label: 'Resolvido', color: 'bg-green-500' },
};

export default function FeedbackManager() {
  const queryClient = useQueryClient();

  const { data: feedbacks = [], isLoading } = useQuery({
    queryKey: ['feedbacks'],
    queryFn: () => base44.entities.Feedback.list('-created_date'),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }) => base44.entities.Feedback.update(id, data),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['feedbacks'] }),
  });

  if (isLoading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="w-6 h-6 animate-spin text-[#1e3a5f]" />
      </div>
    );
  }

  const pendingCount = feedbacks.filter(f => f.status === 'pending').length;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <MessageSquare className="w-5 h-5" />
          Dúvidas e Sugestões
          {pendingCount > 0 && (
            <Badge className="bg-orange-500 text-white ml-1">{pendingCount} novo{pendingCount !== 1 ? 's' : ''}</Badge>
          )}
        </CardTitle>
      </CardHeader>
      <CardContent>
        {feedbacks.length === 0 ? (
          <p className="text-center text-slate-500 py-4">Nenhum feedback recebido</p>
        ) : (
          <div className="space-y-3">
            {feedbacks.map((feedback) => {
              const config = statusConfig[feedback.status] || statusConfig.pending;
              return (
                <div key={feedback.id} className="p-4 bg-slate-50 rounded-lg">
                  <div className="flex items-start justify-between gap-2 mb-2">
                    <div>
                      <p className="font-medium text-sm text-slate-800">
                        {feedback.user_name || feedback.user_email || 'Anônimo'}
                      </p>
                      {feedback.created_date && (
                        <p className="text-xs text-slate-400">
                          {format(new Date(feedback.created_date), 'dd/MM/yyyy HH:mm', { locale: ptBR })}
                        </p>
                      )}
                    </div>
                    <Badge className={`${config.color} text-white text-xs flex-shrink-0`}>{config.label}</Badge>
                  </div>
                  <p className="text-sm text-slate-700 mb-3 whitespace-pre-wrap">{feedback.message}</p>
                  <div className="flex gap-2">
                    {feedback.status === 'pending' && (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => updateMutation.mutate({ id: feedback.id, data: { status: 'read' } })}
                        className="text-xs"
                      >
                        Marcar como lido
                      </Button>
                    )}
                    {feedback.status !== 'resolved' && (
                      <Button
                        size="sm"
                        onClick={() => updateMutation.mutate({ id: feedback.id, data: { status: 'resolved' } })}
                        className="bg-green-600 hover:bg-green-700 text-xs"
                      >
                        <Check className="w-3 h-3 mr-1" />
                        Resolver
                      </Button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
}