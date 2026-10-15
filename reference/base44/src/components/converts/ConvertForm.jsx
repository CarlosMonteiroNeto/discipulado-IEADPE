import React, { useState, useEffect } from 'react';
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { CalendarIcon, Save, X, Loader2 } from "lucide-react";
import PhotoUpload from './PhotoUpload';
import { WORSHIP_TYPES } from '@/utils/worshipTypes';

export default function ConvertForm({ 
  convert, 
  congregations, 
  onSave, 
  onCancel,
  isLoading 
}) {
  const [formData, setFormData] = useState({
    congregation_id: '',
    photo_url: '',
    name: '',
    address: '',
    landmark: '',
    phone: '',
    age: '',
    gender: '',
    conversion_date: null,
    worship_type: '',
  });

  const [errors, setErrors] = useState({});

  useEffect(() => {
    if (convert) {
      setFormData({
        congregation_id: convert.congregation_id || '',
        photo_url: convert.photo_url || '',
        name: convert.name || '',
        address: convert.address || '',
        landmark: convert.landmark || '',
        phone: convert.phone || '',
        age: convert.age || '',
        gender: convert.gender || '',
        conversion_date: convert.conversion_date ? new Date(convert.conversion_date + 'T12:00:00') : null,
        worship_type: convert.worship_type || '',
      });
    }
  }, [convert]);

  const validate = () => {
    const newErrors = {};
    if (!formData.name.trim()) newErrors.name = 'Nome é obrigatório';
    if (!formData.landmark.trim()) newErrors.landmark = 'Ponto de referência é obrigatório';
    if (!formData.gender) newErrors.gender = 'Gênero é obrigatório';
    if (!formData.conversion_date) newErrors.conversion_date = 'Data de conversão é obrigatória';
    if (!formData.worship_type) newErrors.worship_type = 'Tipo de culto é obrigatório';
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!validate()) return;

    const dataToSave = {
      ...formData,
      age: formData.age ? parseInt(formData.age) : null,
      conversion_date: format(formData.conversion_date, 'yyyy-MM-dd'),
      congregation_id: formData.congregation_id || null,
    };

    // If new convert, set initial values
    if (!convert) {
      dataToSave.last_visit_date = dataToSave.conversion_date;
      dataToSave.was_visited_once = false;
      dataToSave.is_in_discipleship = false;
    }

    onSave(dataToSave);
  };

  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: null }));
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* Photo */}
      <div className="flex justify-center">
        <PhotoUpload
          value={formData.photo_url}
          onChange={(url) => handleChange('photo_url', url)}
        />
      </div>

      {/* Congregation */}
      <div className="space-y-2">
        <Label htmlFor="congregation">
          Congregação
          <span className="text-orange-500 text-xs ml-2">(destacado se não preenchido)</span>
        </Label>
        <Select
          value={formData.congregation_id}
          onValueChange={(value) => handleChange('congregation_id', value)}
        >
          <SelectTrigger className={!formData.congregation_id ? 'border-orange-300 bg-orange-50' : ''}>
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
      </div>

      {/* Name */}
      <div className="space-y-2">
        <Label htmlFor="name">Nome *</Label>
        <Input
          id="name"
          value={formData.name}
          onChange={(e) => handleChange('name', e.target.value)}
          placeholder="Nome completo"
          className={errors.name ? 'border-red-500' : ''}
        />
        {errors.name && <p className="text-red-500 text-xs">{errors.name}</p>}
      </div>

      {/* Address */}
      <div className="space-y-2">
        <Label htmlFor="address">Endereço</Label>
        <Input
          id="address"
          value={formData.address}
          onChange={(e) => handleChange('address', e.target.value)}
          placeholder="Endereço completo"
        />
      </div>

      {/* Landmark */}
      <div className="space-y-2">
        <Label htmlFor="landmark">Ponto de Referência *</Label>
        <Input
          id="landmark"
          value={formData.landmark}
          onChange={(e) => handleChange('landmark', e.target.value)}
          placeholder="Ex: Próximo à padaria do João"
          className={errors.landmark ? 'border-red-500' : ''}
        />
        {errors.landmark && <p className="text-red-500 text-xs">{errors.landmark}</p>}
      </div>

      {/* Phone */}
      <div className="space-y-2">
        <Label htmlFor="phone">
          Telefone
          <span className="text-orange-500 text-xs ml-2">(destacado se não preenchido)</span>
        </Label>
        <Input
          id="phone"
          value={formData.phone}
          onChange={(e) => handleChange('phone', e.target.value)}
          placeholder="(00) 00000-0000"
          className={!formData.phone ? 'border-orange-300 bg-orange-50' : ''}
        />
      </div>

      {/* Age */}
      <div className="space-y-2">
        <Label htmlFor="age">Idade</Label>
        <Input
          id="age"
          type="number"
          value={formData.age}
          onChange={(e) => handleChange('age', e.target.value)}
          placeholder="Idade"
          min="0"
          max="150"
        />
      </div>

      {/* Gender */}
      <div className="space-y-2">
        <Label>Gênero *</Label>
        <RadioGroup
          value={formData.gender}
          onValueChange={(value) => handleChange('gender', value)}
          className="flex gap-6"
        >
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="male" id="male" />
            <Label htmlFor="male" className="cursor-pointer">Masculino</Label>
          </div>
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="female" id="female" />
            <Label htmlFor="female" className="cursor-pointer">Feminino</Label>
          </div>
        </RadioGroup>
        {errors.gender && <p className="text-red-500 text-xs">{errors.gender}</p>}
      </div>

      {/* Conversion Date */}
      <div className="space-y-2">
        <Label>Data de Conversão *</Label>
        <Popover>
          <PopoverTrigger asChild>
            <Button
              variant="outline"
              className={`w-full justify-start text-left font-normal ${
                errors.conversion_date ? 'border-red-500' : ''
              }`}
            >
              <CalendarIcon className="mr-2 h-4 w-4" />
              {formData.conversion_date ? (
                format(formData.conversion_date, 'dd/MM/yyyy', { locale: ptBR })
              ) : (
                <span className="text-muted-foreground">Selecione a data</span>
              )}
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-auto p-0" align="start">
            <Calendar
              mode="single"
              selected={formData.conversion_date}
              onSelect={(date) => handleChange('conversion_date', date)}
              locale={ptBR}
              disabled={(date) => date > new Date()}
            />
          </PopoverContent>
        </Popover>
        {errors.conversion_date && <p className="text-red-500 text-xs">{errors.conversion_date}</p>}
      </div>

      {/* Worship Type */}
      <div className="space-y-2">
        <Label>Tipo de Culto *</Label>
        <Select
          value={formData.worship_type}
          onValueChange={(value) => handleChange('worship_type', value)}
        >
          <SelectTrigger className={errors.worship_type ? 'border-red-500' : ''}>
            <SelectValue placeholder="Selecione o tipo de culto" />
          </SelectTrigger>
          <SelectContent>
            {WORSHIP_TYPES.map((type) => (
              <SelectItem key={type} value={type}>
                {type}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        {errors.worship_type && <p className="text-red-500 text-xs">{errors.worship_type}</p>}
      </div>

      {/* Action Buttons */}
      <div className="flex gap-3 pt-4">
        <Button
          type="button"
          variant="outline"
          onClick={onCancel}
          className="flex-1"
          disabled={isLoading}
        >
          <X className="w-4 h-4 mr-2" />
          Cancelar
        </Button>
        <Button
          type="submit"
          className="flex-1 bg-[#1e3a5f] hover:bg-[#2563eb]"
          disabled={isLoading}
        >
          {isLoading ? (
            <Loader2 className="w-4 h-4 mr-2 animate-spin" />
          ) : (
            <Save className="w-4 h-4 mr-2" />
          )}
          {convert ? 'Atualizar' : 'Cadastrar'}
        </Button>
      </div>
    </form>
  );
}