#!/bin/bash

# Test script para verificación rápida del proyecto Astro

echo "🧪 APULATI - Astro Test Suite"
echo "=============================="
echo ""

cd "$(dirname "$0")"

# Check dependencies
echo "📦 Verificando dependencias..."
if [ ! -d "node_modules" ]; then
  echo "❌ node_modules no encontrado. Ejecutando npm install..."
  npm install
else
  echo "✅ Dependencias instaladas"
fi

echo ""
echo "🔍 Verificando estructura del proyecto..."

# Check critical files
files=(
  "src/components/VideoPlayer.tsx"
  "src/components/VideoGrid.tsx"
  "src/utils/hlsManager.ts"
  "src/utils/videoResourceManager.ts"
  "src/utils/googleSheetsManager.ts"
  "src/pages/index.astro"
  "src/pages/theatre-works.astro"
  "astro.config.mjs"
)

all_ok=true
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "✅ $file"
  else
    echo "❌ $file - NO ENCONTRADO"
    all_ok=false
  fi
done

echo ""
echo "🎬 Verificando acceso a assets del proyecto padre..."
if [ -d "../public/assets/videos" ]; then
  video_count=$(find ../public/assets/videos -name "*.mp4" -o -name "*.m3u8" | wc -l)
  echo "✅ Encontrados $video_count archivos de video"
else
  echo "⚠️ Directorio ../public/assets/videos no encontrado"
fi

echo ""
if [ "$all_ok" = true ]; then
  echo "✅ Todos los archivos críticos están presentes"
  echo ""
  echo "🚀 Para iniciar el servidor de desarrollo:"
  echo "   npm run dev"
  echo ""
  echo "🌐 Luego abre: http://localhost:4321"
  echo ""
  echo "📄 Páginas disponibles:"
  echo "   - http://localhost:4321/ (Home)"
  echo "   - http://localhost:4321/theatre-works (Theatre Works)"
else
  echo "❌ Algunos archivos críticos faltan. Revisa la instalación."
  exit 1
fi
