import React, { useState } from 'react';
import { base44 } from '@/api/base44Client';
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { MessageCircle, Loader2 } from "lucide-react";
import { toast } from "sonner";

export default function FeedbackButton() {
  const [open, setOpen] = useState(false);
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    if (!message.trim()) return;
    setLoading(true);
    const user = await base44.auth.me().catch(() => null);
    await base44.entities.Feedback.create({
      user_email: user?.email || '',
      user_name: user?.full_name || '',
      message: message.trim(),
      status: 'pending',
    });
    toast.success('Mensagem enviada! Obrigado pelo feedback.');
    setMessage('');
    setOpen(false);
    setLoading(false);
  };

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="fixed bottom-20 right-4 md:bottom-6 md:right-6 bg-[#1e3a5f] text-white rounded-full px-4 py-3 shadow-lg flex items-center gap-2 z-40 hover:bg-[#2563eb] transition-colors text-sm font-medium"
      >
        <MessageCircle className="w-4 h-4" />
        <span className="hidden sm:inline">Dúvidas e sugestões</span>
        <span className="sm:hidden">Dúvidas</span>
      </button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <MessageCircle className="w-5 h-5 text-[#1e3a5f]" />
              Dúvidas e Sugestões
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <p className="text-sm text-slate-600">
              Compartilhe suas dúvidas, sugestões ou relate um erro encontrado. Sua mensagem será analisada pela equipe.
            </p>
            <Textarea
              placeholder="Escreva sua mensagem aqui..."
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              rows={5}
              className="resize-none"
            />
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setOpen(false)} disabled={loading}>
                Cancelar
              </Button>
              <Button
                onClick={handleSubmit}
                disabled={loading || !message.trim()}
                className="bg-[#1e3a5f] hover:bg-[#2563eb]"
              >
                {loading && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
                Enviar
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}