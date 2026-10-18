import React, { useRef, useState } from 'react';
import { Button } from "@/components/ui/button";
import { Camera, Upload, X } from "lucide-react";
import { base44 } from '@/api/base44Client';

export default function PhotoUpload({ value, onChange }) {
  const fileInputRef = useRef(null);
  const [loading, setLoading] = useState(false);

  const processImage = async (file) => {
    return new Promise((resolve) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          const canvas = document.createElement('canvas');
          const size = 192;
          canvas.width = size;
          canvas.height = size;
          const ctx = canvas.getContext('2d');
          
          // Calculate crop dimensions for square
          const minDim = Math.min(img.width, img.height);
          const sx = (img.width - minDim) / 2;
          const sy = (img.height - minDim) / 2;
          
          ctx.drawImage(img, sx, sy, minDim, minDim, 0, 0, size, size);
          
          canvas.toBlob((blob) => {
            resolve(new File([blob], 'photo.jpg', { type: 'image/jpeg' }));
          }, 'image/jpeg', 0.9);
        };
        img.src = e.target.result;
      };
      reader.readAsDataURL(file);
    });
  };

  const handleFileSelect = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setLoading(true);
    const processedFile = await processImage(file);
    const { file_url } = await base44.integrations.Core.UploadFile({ file: processedFile });
    onChange(file_url);
    setLoading(false);
  };

  return (
    <div className="flex flex-col items-center gap-3">
      <div className="relative">
        {value ? (
          <div className="relative">
            <img
              src={value}
              alt="Foto"
              className="w-24 h-24 rounded-full object-cover border-4 border-[#1e3a5f]"
            />
            <button
              type="button"
              onClick={() => onChange('')}
              className="absolute -top-1 -right-1 bg-red-500 text-white rounded-full p-1 hover:bg-red-600 transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        ) : (
          <div className="w-24 h-24 rounded-full bg-slate-100 border-2 border-dashed border-slate-300 flex items-center justify-center">
            <Camera className="w-8 h-8 text-slate-400" />
          </div>
        )}
      </div>
      
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        capture="environment"
        onChange={handleFileSelect}
        className="hidden"
      />
      
      <Button
        type="button"
        variant="outline"
        size="sm"
        onClick={() => fileInputRef.current?.click()}
        disabled={loading}
        className="border-[#1e3a5f] text-[#1e3a5f] hover:bg-[#1e3a5f] hover:text-white"
      >
        {loading ? (
          <span className="animate-pulse">Processando...</span>
        ) : (
          <>
            <Upload className="w-4 h-4 mr-2" />
            {value ? 'Trocar foto' : 'Adicionar foto'}
          </>
        )}
      </Button>
    </div>
  );
}