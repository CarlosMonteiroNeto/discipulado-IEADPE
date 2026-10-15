import React, { useState } from 'react';
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
import { Plus, Pencil, Trash2, Church, Save, X, Loader2 } from "lucide-react";
import { base44 } from '@/api/base44Client';
import { toast } from "sonner";

export default function CongregationManager({ congregations, onRefresh }) {
  const [showForm, setShowForm] = useState(false);
  const [editingCongregation, setEditingCongregation] = useState(null);
  const [name, setName] = useState('');
  const [deleteId, setDeleteId] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleEdit = (cong) => {
    setEditingCongregation(cong);
    setName(cong.name);
    setShowForm(true);
  };

  const handleCancel = () => {
    setShowForm(false);
    setEditingCongregation(null);
    setName('');
  };

  const handleSave = async () => {
    if (!name.trim()) {
      toast.error('Nome é obrigatório');
      return;
    }

    setLoading(true);
    if (editingCongregation) {
      await base44.entities.Congregation.update(editingCongregation.id, { name: name.trim() });
      toast.success('Congregação atualizada!');
    } else {
      await base44.entities.Congregation.create({ name: name.trim() });
      toast.success('Congregação cadastrada!');
    }
    setLoading(false);
    handleCancel();
    onRefresh();
  };

  const handleDelete = async () => {
    if (!deleteId) return;
    setLoading(true);
    await base44.entities.Congregation.delete(deleteId);
    toast.success('Congregação excluída!');
    setLoading(false);
    setDeleteId(null);
    onRefresh();
  };

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle className="flex items-center gap-2">
          <Church className="w-5 h-5" />
          Congregações
        </CardTitle>
        {!showForm && (
          <Button
            onClick={() => setShowForm(true)}
            className="bg-[#1e3a5f] hover:bg-[#2563eb]"
            size="sm"
          >
            <Plus className="w-4 h-4 mr-1" />
            Nova
          </Button>
        )}
      </CardHeader>
      <CardContent>
        {showForm && (
          <div className="flex gap-2 mb-4">
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Nome da congregação"
              className="flex-1"
              autoFocus
            />
            <Button
              onClick={handleSave}
              disabled={loading}
              className="bg-green-600 hover:bg-green-700"
              size="icon"
            >
              {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            </Button>
            <Button
              onClick={handleCancel}
              variant="outline"
              size="icon"
              disabled={loading}
            >
              <X className="w-4 h-4" />
            </Button>
          </div>
        )}

        <div className="space-y-2">
          {congregations.length === 0 ? (
            <p className="text-center text-slate-500 py-4">
              Nenhuma congregação cadastrada
            </p>
          ) : (
            congregations.map((cong) => (
              <div
                key={cong.id}
                className="flex items-center justify-between p-3 bg-slate-50 rounded-lg"
              >
                <span className="font-medium">{cong.name}</span>
                <div className="flex gap-1">
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => handleEdit(cong)}
                    className="h-8 w-8"
                  >
                    <Pencil className="w-4 h-4 text-[#1e3a5f]" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => setDeleteId(cong.id)}
                    className="h-8 w-8"
                  >
                    <Trash2 className="w-4 h-4 text-red-500" />
                  </Button>
                </div>
              </div>
            ))
          )}
        </div>
      </CardContent>

      <AlertDialog open={!!deleteId} onOpenChange={() => setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmar exclusão</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir esta congregação? Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              className="bg-red-600 hover:bg-red-700"
            >
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </Card>
  );
}