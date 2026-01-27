# 🚀 Deployment Guide

## Automatic Deployment

This project is configured with GitHub Actions for automatic deployment to GitHub Pages.

### How it works:

1. **Trigger**: Every push to `main` branch automatically triggers the deployment
2. **Build**: The action runs `npm run build` to create the production build
3. **Deploy**: The built files are automatically deployed to GitHub Pages

### Manual Deployment:

You can also trigger deployment manually:
1. Go to the "Actions" tab in GitHub
2. Select "Build and Deploy to GitHub Pages"
3. Click "Run workflow"

### Configuration:

- **Base URL**: Automatically configured for production (`/apulati/`) and development (`/`)
- **Build Output**: Located in `dist/` directory
- **Node Version**: 18.x
- **Dependencies**: Automatically cached for faster builds

### Environment Variables:

- `NODE_ENV=production` is set during build for optimizations

### Monitoring:

Check the Actions tab to monitor deployment status and view logs if issues arise.

### URLs:

- **Development**: `http://localhost:5173/`
- **Production**: `https://[username].github.io/apulati/` 