import React, { useState } from 'react';
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
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
import {
  Dialog,
  DialogContent,
} from "@/components/ui/dialog";
import { MessageCircle, Pencil, Trash2, User, MapPin, Phone, Calendar, Church, AlertCircle, BookOpen } from "lucide-react";
import { format, differenceInDays } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default function ConvertCard({ 
  convert, 
  congregation,
  onEdit, 
  onDelete, 
  onUpdateDiscipleship,
  onMarkVisited,
  onMarkDiscipleshipCompleted,
  onMarkDeviated
}) {
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [showDiscipleshipDialog, setShowDiscipleshipDialog] = useState(false);
  const [showVisitDialog, setShowVisitDialog] = useState(false);
  const [showPhotoZoom, setShowPhotoZoom] = useState(false);
  const [showCompletedDialog, setShowCompletedDialog] = useState(false);
  const [showDeviatedDialog, setShowDeviatedDialog] = useState(false);

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

  const daysSinceDiscipleship = convert.discipleship_start_date
    ? differenceInDays(today, new Date(convert.discipleship_start_date))
    : 0;
  const showCompletedCheckbox = convert.is_in_discipleship && daysSinceDiscipleship >= 90 && !convert.is_discipleship_completed;
  const showDeviatedCheckbox = (convert.visit_count || 0) >= 3 && !convert.is_deviated && !convert.is_discipleship_completed;

  // Determine card color
  let cardColor = 'bg-yellow-50 border-yellow-400';
  let statusText = 'Atenção';
  let statusColor = 'bg-yellow-500';

  if (needsVisit && !convert.is_in_discipleship) {
    cardColor = 'bg-red-50 border-red-400';
    statusText = 'Visita Urgente';
    statusColor = 'bg-red-500';
  } else if (!needsVisit && convert.is_in_discipleship) {
    cardColor = 'bg-green-50 border-green-400';
    statusText = 'Em dia';
    statusColor = 'bg-green-500';
  }

  const handleWhatsApp = () => {
    if (!convert.phone) return;
    const phone = convert.phone.replace(/\D/g, '');
    const phoneWithCountry = phone.startsWith('55') ? phone : `55${phone}`;
    window.open(`https://wa.me/${phoneWithCountry}`, '_blank');
  };

  const handleDiscipleshipChange = () => {
    if (!convert.is_in_discipleship) {
      setShowDiscipleshipDialog(true);
    } else {
      onUpdateDiscipleship(convert.id, false);
    }
  };

  const handleVisitChange = () => {
    if (needsVisit) {
      setShowVisitDialog(true);
    }
  };

  const confirmDiscipleship = () => {
    onUpdateDiscipleship(convert.id, true);
    setShowDiscipleshipDialog(false);
  };

  const confirmVisit = () => {
    onMarkVisited(convert.id);
    setShowVisitDialog(false);
  };

  const confirmCompleted = () => {
    onMarkDiscipleshipCompleted(convert.id);
    setShowCompletedDialog(false);
  };

  const confirmDeviated = () => {
    onMarkDeviated(convert.id);
    setShowDeviatedDialog(false);
  };

  const missingInfo = !convert.congregation_id || !convert.phone;

  return (
    <>
      <Card className={`${cardColor} border-2 overflow-hidden transition-all hover:shadow-lg`}>
        <div className={`${statusColor} text-white px-4 py-2 flex justify-between items-center`}>
          <span className="font-semibold text-sm">{statusText}</span>
          <span className="text-xs opacity-90">
            {daysSinceLastVisit} dias desde última visita
          </span>
        </div>

        <div className="p-4">
          <div className="flex gap-4 mb-4">
            <div className="flex-shrink-0">
              {convert.photo_url ? (
                <img
                  src={convert.photo_url}
                  alt={convert.name}
                  className="w-20 h-20 rounded-full object-cover border-4 border-white shadow-md cursor-pointer hover:opacity-80 transition-opacity"
                  onClick={() => setShowPhotoZoom(true)}
                />
              ) : (
                <div className="w-20 h-20 rounded-full bg-slate-200 flex items-center justify-center border-4 border-white shadow-md">
                  <User className="w-10 h-10 text-slate-400" />
                </div>
              )}
            </div>

            <div className="flex-1 min-w-0">
              <h3 className="font-bold text-lg text-slate-800 truncate">{convert.name}</h3>
              
              {congregation && (
                <div className="flex items-center gap-1 text-sm text-slate-600 mt-1">
                  <Church className="w-4 h-4" />
                  <span className="truncate">{congregation.name}</span>
                </div>
              )}

              {convert.address && (
                <div className="flex items-center gap-1 text-sm text-slate-600 mt-1">
                  <MapPin className="w-4 h-4" />
                  <span className="truncate">{convert.address}</span>
                </div>
              )}

              <div className="flex items-center gap-1 text-sm text-slate-600 mt-1">
                <MapPin className="w-4 h-4 flex-shrink-0" />
                <span className="truncate text-xs">{convert.landmark}</span>
              </div>

              {convert.phone && (
                <div className="flex items-center gap-1 text-sm text-slate-600 mt-1">
                  <Phone className="w-4 h-4" />
                  <span>{convert.phone}</span>
                </div>
              )}
            </div>
          </div>

          {missingInfo && (
            <div className="bg-orange-100 border border-orange-300 rounded-lg p-2 mb-3 flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-orange-600" />
              <span className="text-xs text-orange-700">
                {!convert.congregation_id && 'Congregação não informada. '}
                {!convert.phone && 'Telefone não informado.'}
              </span>
            </div>
          )}

          <div className="grid grid-cols-2 gap-2 text-xs text-slate-600 mb-3">
            <div className="flex items-center gap-1">
              <Calendar className="w-3 h-3" />
              <span>Conversão: {format(new Date(convert.conversion_date), 'dd/MM/yyyy', { locale: ptBR })}</span>
            </div>
            <div className="flex items-center gap-1">
              <Calendar className="w-3 h-3" />
              <span>Última visita: {format(lastVisit, 'dd/MM/yyyy', { locale: ptBR })}</span>
            </div>
          </div>

          {convert.worship_type && (
            <div className="flex items-center gap-1 text-xs text-slate-600 mb-3">
              <BookOpen className="w-3 h-3 flex-shrink-0" />
              <span className="truncate">{convert.worship_type}</span>
            </div>
          )}

          <div className="flex flex-wrap gap-2 mb-4">
            {convert.is_in_discipleship && (
              <Badge className="bg-green-600">Em Discipulado</Badge>
            )}
            {convert.was_visited_once && (
              <Badge variant="outline" className="border-blue-500 text-blue-600">Já visitado</Badge>
            )}
            {(convert.visit_count || 0) > 0 && (
              <Badge variant="outline" className="border-slate-400">{convert.visit_count} visita{convert.visit_count !== 1 ? 's' : ''}</Badge>
            )}
            {convert.gender === 'male' ? (
              <Badge variant="outline">Masculino</Badge>
            ) : (
              <Badge variant="outline">Feminino</Badge>
            )}
            {convert.age && (
              <Badge variant="outline">{convert.age} anos</Badge>
            )}
          </div>

          {/* Checkboxes */}
          <div className="space-y-2 mb-4 p-3 bg-white/50 rounded-lg">
            {!convert.is_in_discipleship && (
              <div className="flex items-center space-x-2">
                <Checkbox
                  id={`discipleship-${convert.id}`}
                  checked={convert.is_in_discipleship}
                  onCheckedChange={handleDiscipleshipChange}
                />
                <label htmlFor={`discipleship-${convert.id}`} className="text-sm font-medium cursor-pointer">
                  Iniciou discipulado
                </label>
              </div>
            )}
            
            {needsVisit && (
              <div className="flex items-center space-x-2">
                <Checkbox
                  id={`visit-${convert.id}`}
                  checked={false}
                  onCheckedChange={handleVisitChange}
                />
                <label htmlFor={`visit-${convert.id}`} className="text-sm font-medium cursor-pointer">
                  Visita realizada/entramos em contato
                </label>
              </div>
            )}

            {showCompletedCheckbox && (
              <div className="flex items-center space-x-2 p-2 bg-green-50 rounded border border-green-200">
                <Checkbox
                  id={`completed-${convert.id}`}
                  checked={false}
                  onCheckedChange={() => setShowCompletedDialog(true)}
                />
                <label htmlFor={`completed-${convert.id}`} className="text-sm font-medium cursor-pointer text-green-700">
                  Concluiu o discipulado
                </label>
              </div>
            )}

            {showDeviatedCheckbox && (
              <div className="flex items-center space-x-2 p-2 bg-red-50 rounded border border-red-200">
                <Checkbox
                  id={`deviated-${convert.id}`}
                  checked={false}
                  onCheckedChange={() => setShowDeviatedDialog(true)}
                />
                <label htmlFor={`deviated-${convert.id}`} className="text-sm font-medium cursor-pointer text-red-700">
                  Desviou-se
                </label>
              </div>
            )}
          </div>

          <div className="flex gap-2">
            {convert.phone && (
              <Button size="sm" className="bg-green-600 hover:bg-green-700 flex-1" onClick={handleWhatsApp}>
                <MessageCircle className="w-4 h-4 mr-1" />
                WhatsApp
              </Button>
            )}
            <Button size="sm" variant="outline" onClick={() => onEdit(convert)} className="border-[#1e3a5f] text-[#1e3a5f]">
              <Pencil className="w-4 h-4" />
            </Button>
            <Button size="sm" variant="outline" onClick={() => setShowDeleteDialog(true)} className="border-red-500 text-red-500 hover:bg-red-50">
              <Trash2 className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </Card>

      <AlertDialog open={showDeleteDialog} onOpenChange={setShowDeleteDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmar exclusão</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir o cadastro de <strong>{convert.name}</strong>? Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={() => onDelete(convert.id)} className="bg-red-600 hover:bg-red-700">Excluir</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={showDiscipleshipDialog} onOpenChange={setShowDiscipleshipDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Iniciou Discipulado</AlertDialogTitle>
            <AlertDialogDescription>
              Confirma que <strong>{convert.name}</strong> está iniciando o discipulado?
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={confirmDiscipleship} className="bg-green-600 hover:bg-green-700">Confirmar</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={showVisitDialog} onOpenChange={setShowVisitDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Registrar Visita</AlertDialogTitle>
            <AlertDialogDescription>
              Confirma que <strong>{convert.name}</strong> foi visitado hoje?
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={confirmVisit} className="bg-[#1e3a5f] hover:bg-[#2563eb]">Confirmar</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={showCompletedDialog} onOpenChange={setShowCompletedDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Concluiu o Discipulado</AlertDialogTitle>
            <AlertDialogDescription>
              Confirma que <strong>{convert.name}</strong> concluiu o discipulado? Esta ficha será arquivada.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={confirmCompleted} className="bg-green-600 hover:bg-green-700">Confirmar</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={showDeviatedDialog} onOpenChange={setShowDeviatedDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Registrar Desvio</AlertDialogTitle>
            <AlertDialogDescription>
              Confirma que <strong>{convert.name}</strong> se desviou? Esta ficha será movida para o registro de desviados.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={confirmDeviated} className="bg-red-600 hover:bg-red-700">Confirmar</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {convert.photo_url && (
        <Dialog open={showPhotoZoom} onOpenChange={setShowPhotoZoom}>
          <DialogContent className="max-w-3xl p-0 overflow-hidden">
            <img src={convert.photo_url} alt={convert.name} className="w-full h-auto" />
          </DialogContent>
        </Dialog>
      )}
    </>
  );
}