# 🚀 Despliegue en Vercel - APULATI Astro

## Opción 1: Deploy Automático desde GitHub

### Preparación
1. Asegúrate de que el código está en un repositorio Git
2. Sube los cambios a GitHub:
```bash
cd /Users/david/Documents/GitHub/baptiste
git add astro-app/
git commit -m "feat: migración a Astro completada"
git push origin main
```

### Deploy en Vercel
1. Ve a https://vercel.com
2. Click en "New Project"
3. Importa tu repositorio de GitHub
4. Configura:
   - **Framework Preset**: Astro
   - **Root Directory**: `astro-app`
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`

### Variables de Entorno (si es necesario)
```
# Ninguna requerida actualmente
# Google Sheets API key está hardcoded (considera moverlo a variable de entorno)
```

---

## Opción 2: Deploy Manual con Vercel CLI

### Instalar Vercel CLI
```bash
npm install -g vercel
```

### Login
```bash
vercel login
```

### Deploy
```bash
cd astro-app
vercel
```

Sigue las instrucciones en pantalla.

---

## Configuración de Vercel

El archivo `vercel.json` ya está configurado:

```json
{
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/"
    }
  ]
}
```

Esto asegura que el routing de Astro funcione correctamente.

---

## Build Local (Pre-deploy)

Antes de hacer deploy, verifica que el build funciona:

```bash
cd astro-app

# Build
npm run build

# Preview local del build
npm run preview
```

El preview estará disponible en http://localhost:4321

---

## Checklist Pre-Deploy

- [ ] Build local exitoso (`npm run build`)
- [ ] Preview funciona correctamente (`npm run preview`)
- [ ] No hay errores en consola del navegador
- [ ] Videos cargan y reproducen correctamente
- [ ] Rutas de assets son relativas (no localhost)
- [ ] Google Sheets API key funciona
- [ ] Thumbnails se muestran correctamente

---

## Post-Deploy

### Verificación
1. Visita la URL de producción
2. Abre la consola del navegador (F12)
3. Verifica:
   - No hay errores 404
   - Videos cargan correctamente
   - HLS funciona
   - Datos de Google Sheets se cargan

### Dominio Personalizado (Opcional)
1. En Vercel Dashboard → Settings → Domains
2. Añade tu dominio personalizado
3. Configura DNS según las instrucciones

---

## Monitoreo

### Vercel Analytics
Puedes activar Vercel Analytics para monitorear:
- Tiempos de carga
- Core Web Vitals
- Tráfico

### Logs
Los logs están disponibles en:
- Vercel Dashboard → Deployments → [tu deploy] → Functions

---

## Troubleshooting en Producción

### Videos no cargan
- Verifica que `publicDir: '../public'` funciona en producción
- Considera mover assets a CDN si es necesario
- Revisa configuración de CORS

### HLS no funciona
- Verifica que hls.js se está bundleando correctamente
- Revisa errores en consola del navegador
- Considera usar CDN para hls.js si hay problemas

### Errores de SSR
- Asegúrate de que todo el código de navegador está dentro de checks `typeof window !== 'undefined'`
- Revisa que imports dinámicos funcionan correctamente

---

## Rollback

Si algo sale mal, puedes hacer rollback en Vercel:
1. Dashboard → Deployments
2. Encuentra un deploy anterior que funcionaba
3. Click en los 3 puntos → "Promote to Production"

---

## CI/CD (Opcional)

Para deploys automáticos en cada push:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Vercel

on:
  push:
    branches: [main]
    paths:
      - 'astro-app/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Vercel CLI
        run: npm install -g vercel
      - name: Deploy
        run: |
          cd astro-app
          vercel --prod --token=${{ secrets.VERCEL_TOKEN }}
```

---

## Performance Tips

### Imágenes
Considera usar Astro Image para optimización automática:
```bash
npm install @astrojs/image
```

### Prefetch
Para navegación más rápida:
```astro
---
// Añade prefetch a links
---
<a href="/theatre-works" data-astro-prefetch>Theatre Works</a>
```

### Caching
Vercel cachea automáticamente assets estáticos. Para assets grandes (videos), considera:
- Vercel Blob Storage
- Cloudflare R2
- AWS S3 + CloudFront

---

## Costos

### Vercel Free Tier
- 100GB bandwidth/mes
- Ilimitados deployments
- Análisis básico

### Consideraciones
Con 374 archivos de video, el bandwidth puede ser un factor. Monitorea el uso y considera:
- Mover videos a CDN externo
- Implementar lazy loading más agresivo
- Usar video streaming service (Vimeo, YouTube, etc.)

---

## Soporte

Si encuentras problemas:
1. Revisa [Astro Docs](https://docs.astro.build)
2. Consulta [Vercel Docs](https://vercel.com/docs)
3. Revisa logs en Vercel Dashboard
4. Busca en [Astro Discord](https://astro.build/chat)

---

*Última actualización: 21 de enero de 2026*
