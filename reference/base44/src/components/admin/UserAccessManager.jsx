import React, { useState } from 'react';
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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
import { Plus, Pencil, Trash2, Users, Save, X, Loader2, Church, Shield } from "lucide-react";
import { base44 } from '@/api/base44Client';
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";

export default function UserAccessManager({ accesses, congregations, onRefresh }) {
  const [showForm, setShowForm] = useState(false);
  const [editingAccess, setEditingAccess] = useState(null);
  const [email, setEmail] = useState('');
  const [selectedRole, setSelectedRole] = useState('');
  const [selectedCongregation, setSelectedCongregation] = useState('');
  const [deleteId, setDeleteId] = useState(null);
  const [loading, setLoading] = useState(false);
  const [replaceConfirm, setReplaceConfirm] = useState(null);

  const roles = [
    "Membro da direção da campanha",
    "Membro da supervisão das campanhas"
  ];

  const congregationRoles = [
    "Membro da direção da campanha"
  ];

  const handleEdit = (access) => {
    setEditingAccess(access);
    setEmail(access.user_email);
    setSelectedRole(access.role || '');
    setSelectedCongregation(access.congregation_id || '');
    setShowForm(true);
  };

  const handleCancel = () => {
    setShowForm(false);
    setEditingAccess(null);
    setEmail('');
    setSelectedRole('');
    setSelectedCongregation('');
  };

  const handleSave = async () => {
    if (!email.trim()) {
      toast.error('Email é obrigatório');
      return;
    }

    if (!selectedRole) {
      toast.error('Selecione um cargo');
      return;
    }

    const needsCongregation = congregationRoles.includes(selectedRole);
    if (needsCongregation && !selectedCongregation) {
      toast.error('Selecione uma congregação para este cargo');
      return;
    }

    // Check if this specific user already has this role in this congregation
    if (!editingAccess) {
      const existing = accesses.find(
        a => a.user_email === email.trim().toLowerCase() && a.role === selectedRole && a.congregation_id === (needsCongregation ? selectedCongregation : null)
      );
      if (existing) {
        toast.error('Este usuário já possui este acesso.');
        return;
      }
    }

    setLoading(true);

    const data = {
      user_email: email.trim().toLowerCase(),
      role: selectedRole,
      congregation_id: needsCongregation ? selectedCongregation : null
    };

    if (editingAccess) {
      await base44.entities.UserAccess.update(editingAccess.id, data);
      toast.success('Acesso atualizado!');
    } else {
      await base44.entities.UserAccess.create(data);
      toast.success('Acesso concedido!');
    }
    setLoading(false);
    handleCancel();
    onRefresh();
  };

  const handleDelete = async () => {
    if (!deleteId) return;
    setLoading(true);
    await base44.entities.UserAccess.delete(deleteId);
    toast.success('Acesso removido!');
    setLoading(false);
    setDeleteId(null);
    onRefresh();
  };

  const getCongregationName = (id) => {
    if (!id) return 'Todas';
    const cong = congregations.find(c => c.id === id);
    return cong ? cong.name : 'Desconhecida';
  };

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle className="flex items-center gap-2">
          <Users className="w-5 h-5" />
          Gerenciar Acessos
        </CardTitle>
        {!showForm && (
          <Button
            onClick={() => setShowForm(true)}
            className="bg-[#1e3a5f] hover:bg-[#2563eb]"
            size="sm"
          >
            <Plus className="w-4 h-4 mr-1" />
            Novo Acesso
          </Button>
        )}
      </CardHeader>
      <CardContent>
        {showForm && (
          <div className="space-y-4 mb-6 p-4 bg-slate-50 rounded-lg">
            <div className="space-y-2">
              <Label htmlFor="email">Email do usuário</Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="usuario@email.com"
                disabled={!!editingAccess}
              />
            </div>

            <div className="space-y-2">
              <Label>Cargo</Label>
              <Select value={selectedRole} onValueChange={setSelectedRole}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione o cargo" />
                </SelectTrigger>
                <SelectContent>
                  {roles.map((role) => (
                    <SelectItem key={role} value={role}>
                      {role}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {congregationRoles.includes(selectedRole) && (
              <div className="space-y-2">
                <Label>Congregação</Label>
                <Select value={selectedCongregation} onValueChange={setSelectedCongregation}>
                  <SelectTrigger>
                    <SelectValue placeholder="Selecione a congregação" />
                  </SelectTrigger>
                  <SelectContent>
                    {congregations.map((cong) => (
                      <SelectItem key={cong.id} value={cong.id}>
                        {cong.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {congregations.length === 0 && (
                  <p className="text-sm text-slate-500">Cadastre congregações primeiro</p>
                )}
              </div>
            )}

            <div className="flex gap-2">
              <Button
                onClick={handleSave}
                disabled={loading}
                className="bg-green-600 hover:bg-green-700"
              >
                {loading ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Save className="w-4 h-4 mr-2" />}
                Salvar
              </Button>
              <Button
                onClick={handleCancel}
                variant="outline"
                disabled={loading}
              >
                <X className="w-4 h-4 mr-2" />
                Cancelar
              </Button>
            </div>
          </div>
        )}

        <div className="space-y-3">
          {accesses.length === 0 ? (
            <p className="text-center text-slate-500 py-4">
              Nenhum acesso configurado
            </p>
          ) : (
            accesses.map((access) => (
              <div
                key={access.id}
                className="p-4 bg-slate-50 rounded-lg"
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex-1">
                    <span className="font-medium text-[#1e3a5f] block">{access.user_email}</span>
                    <div className="flex items-center gap-2 mt-1">
                      <Badge variant="outline" className="text-xs">
                        <Shield className="w-3 h-3 mr-1" />
                        {access.role}
                      </Badge>
                      {access.congregation_id && (
                        <Badge variant="secondary" className="text-xs">
                          <Church className="w-3 h-3 mr-1" />
                          {getCongregationName(access.congregation_id)}
                        </Badge>
                      )}
                      {!access.congregation_id && (
                        <Badge className="text-xs bg-green-600">
                          Acesso Total
                        </Badge>
                      )}
                    </div>
                  </div>
                  <div className="flex gap-1">
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => handleEdit(access)}
                      className="h-8 w-8"
                    >
                      <Pencil className="w-4 h-4 text-[#1e3a5f]" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => setDeleteId(access.id)}
                      className="h-8 w-8"
                    >
                      <Trash2 className="w-4 h-4 text-red-500" />
                    </Button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </CardContent>

      <AlertDialog open={!!deleteId} onOpenChange={() => setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmar remoção</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja remover o acesso deste usuário? Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              className="bg-red-600 hover:bg-red-700"
            >
              Remover
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

    </Card>
  );
}