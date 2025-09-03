# Safe CLI Deployment Guide

## 🚀 Deploying to Vercel

### Prerequisites
- Vercel account
- Supabase project
- Git repository

### Step 1: Prepare Your Repository

1. **Push your code to GitHub/GitLab/Bitbucket**
2. **Ensure all files are committed:**
   - `server.py` (Flask backend)
   - `frontend/` (HTML, CSS, JS)
   - `vercel.json` (Vercel configuration)
   - `requirements.txt` (Python dependencies)
   - `safe-cli-installer.sh` (Endpoint installer script)

### Step 2: Set Up Supabase

1. **Create a Supabase project** at https://supabase.com
2. **Get your project credentials:**
   - Project URL
   - API Key (anon/public key)
3. **Set up your database tables** using the schema from your project

### Step 3: Deploy to Vercel

1. **Connect to Vercel:**
   - Go to https://vercel.com
   - Import your Git repository
   - Select "Python" as the framework

2. **Set Environment Variables:**
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_KEY`: Your Supabase API key
   - `FLASK_SECRET_KEY`: A random secret key for sessions

3. **Deploy:**
   - Click "Deploy"
   - Wait for deployment to complete
   - Note your deployment URL (e.g., `https://your-app.vercel.app`)

### Step 4: Update Installer Script

After deployment, update the installer script to use your Vercel URL:

1. **Edit `safe-cli-installer.sh`:**
   ```bash
   # Change the default server URL
   DEFAULT_SERVER_URL="https://your-app.vercel.app"
   ```

2. **Update the frontend dashboard URL** in the installer script

### Step 5: Test Deployment

1. **Test the dashboard:**
   - Visit your Vercel URL
   - Create a user account
   - Add commands to blacklist

2. **Test endpoint installation:**
   - Download the installer script
   - Run: `source ./safe-cli-installer.sh`
   - Use your Vercel URL when prompted

## 📁 File Structure for Vercel

```
safe-cli/
├── server.py              # Flask backend
├── vercel.json            # Vercel configuration
├── requirements.txt       # Python dependencies
├── safe-cli-installer.sh  # Endpoint installer
├── frontend/              # Static files
│   ├── index.html
│   ├── login.html
│   ├── register.html
│   ├── styles.css
│   └── app.js
└── DEPLOYMENT.md          # This file
```

## 🔧 Environment Variables

Set these in your Vercel dashboard:

- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_KEY`: Your Supabase API key
- `FLASK_SECRET_KEY`: Random secret for session security

## 🌐 Custom Domain (Optional)

1. **Add custom domain in Vercel dashboard**
2. **Update installer script** with your custom domain
3. **Update DNS records** as instructed by Vercel

## 🔄 Updates

To update your deployment:
1. Push changes to your Git repository
2. Vercel will automatically redeploy
3. Update installer script if server URL changes

## 🐛 Troubleshooting

### Common Issues:

1. **Environment variables not set:**
   - Check Vercel dashboard settings
   - Ensure variable names match exactly

2. **Supabase connection issues:**
   - Verify URL and API key
   - Check Supabase project status

3. **Static files not loading:**
   - Ensure `frontend/` folder is in root directory
   - Check file paths in HTML/CSS

4. **Installer script issues:**
   - Update server URL in script
   - Ensure script is executable: `chmod +x safe-cli-installer.sh`

## 📞 Support

If you encounter issues:
1. Check Vercel deployment logs
2. Check Supabase logs
3. Test locally first
4. Verify environment variables
