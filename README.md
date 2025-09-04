# 🛡️ Safe CLI - Command Security Dashboard

A comprehensive command-line security solution that provides real-time command blocking, approval workflows, and centralized management for Linux/Unix systems.

![Safe CLI Dashboard](https://img.shields.io/badge/Safe%20CLI-Dashboard-blue)
![Python](https://img.shields.io/badge/Python-3.8+-green)
![Flask](https://img.shields.io/badge/Flask-3.1.2-red)
![Supabase](https://img.shields.io/badge/Supabase-Database-orange)
![Vercel](https://img.shields.io/badge/Vercel-Deployed-purple)

## 🌐 Live Demo

**Try Safe CLI now!** The application is currently deployed and ready to test:

🔗 **[https://safe-cli.vercel.app/](https://safe-cli.vercel.app/)**

- **Login**: Use the demo credentials or create a new account
- **Test Features**: Full dashboard functionality available
- **Install Endpoints**: Download and test the agent on your systems
- **Real-time**: All features work in real

https://github.com/user-attachments/assets/83974900-5ec3-46fe-902f-4d0dbfbc0b79

-time with live data

  

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [API Documentation](#api-documentation)
- [Deployment](#deployment)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

Safe CLI is a security-focused command-line interface management system that allows administrators to:

- **Block dangerous commands** in real-time across multiple endpoints
- **Require approval** for sensitive operations before execution
- **Centralize management** through a modern web dashboard
- **Monitor command usage** and security events
- **Deploy easily** to any number of Linux/Unix systems

### Why Safe CLI?

- **Zero-trust approach**: No command executes without verification
- **Real-time blocking**: Commands are intercepted before execution
- **Centralized control**: Manage all endpoints from one dashboard
- **Approval workflows**: Human oversight for critical operations
- **Easy deployment**: One-command installation on any system

## ✨ Features

### 🔒 Security Features
- **Command Blacklisting**: Block dangerous commands (rm, sudo, fdisk, etc.)
- **Real-time Interception**: Commands are blocked before execution
- **Approval Workflows**: Human approval required for blocked commands
- **Session Management**: Secure user authentication and sessions
- **Endpoint Registration**: Secure endpoint identification and management

### 🎨 User Interface
- **Modern Dashboard**: Clean, responsive web interface
- **Real-time Updates**: Live command request monitoring
- **Mobile Responsive**: Works on all device sizes
- **Dark Theme**: Professional dark mode design
- **Interactive Elements**: Smooth animations and transitions

### 🚀 Deployment
- **One-Command Install**: Simple installation script
- **Multiple Installation Types**: Global or single-terminal modes
- **Auto-Configuration**: Automatic endpoint registration
- **Cloud-Ready**: Deploy to Vercel, Heroku, or any cloud provider
- **Docker Support**: Containerized deployment options

### 📊 Management
- **Endpoint Management**: Add, remove, activate/deactivate endpoints
- **Command Management**: Add/remove commands from blacklist
- **Request Monitoring**: View and approve/deny command requests
- **User Management**: Multi-user support with authentication
- **Audit Logging**: Track all security events and decisions

## 🏗️ Architecture

### System Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Dashboard │    │   Flask Server  │    │   Supabase DB   │
│   (Frontend)    │◄──►│   (Backend)     │◄──►│   (Database)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Agent Scripts │    │   API Endpoints │    │   Data Storage  │
│   (Endpoints)   │    │   (REST API)    │    │   (Tables)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Technology Stack

- **Frontend**: HTML5, CSS3, JavaScript (ES6+)
- **Backend**: Python 3.8+, Flask 3.1.2
- **Database**: Supabase (PostgreSQL)
- **Authentication**: bcrypt, session-based
- **Deployment**: Vercel, Docker
- **Agent**: Bash scripting, curl, jq

### Database Schema

- **root_users**: User accounts and authentication
- **endpoints**: Registered systems and their status
- **blacklist**: Commands to block per user
- **approval_requests**: Pending command approvals

## 🚀 Installation

### Prerequisites

- Python 3.8 or higher
- Supabase account
- Git
- Linux/Unix system (for endpoints)

### Quick Start

**Option 1: Try the Live Demo**
- Visit [https://safe-cli.vercel.app/](https://safe-cli.vercel.app/)
- Create an account and start using immediately
- Download the installer script to test on your systems

**Option 2: Deploy Your Own Instance**

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/safe-cli.git
   cd safe-cli
   ```

2. **Set up environment variables**
   ```bash
   cp env_template_production.txt .env
   # Edit .env with your Supabase credentials
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Deploy to Vercel**
   ```bash
   vercel --prod
   ```

### Endpoint Installation

On each system you want to protect:

```bash
# Download and run the installer
curl -s https://your-app.vercel.app/safe-cli-installer.sh | bash
# OR
wget https://your-app.vercel.app/safe-cli-installer.sh
source ./safe-cli-installer.sh
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Required | Vercel |
|----------|-------------|----------|---------|
| `SUPABASE_URL` | Your Supabase project URL | Yes | ✅ |
| `SUPABASE_KEY` | Your Supabase API key (anon/public) | Yes | ✅ |
| `SUPABASE_SERVICE_KEY` | Your Supabase service role key | Yes | ✅ |
| `FLASK_SECRET_KEY` | Secret key for sessions | No | Auto-generated |
| `FLASK_DEBUG` | Debug mode (true/false) | No | Default: false |

> **Note**: For Vercel deployment, only the 3 Supabase variables are required. The Flask secret key is auto-generated by Vercel.

### Supabase Setup

1. Create a new Supabase project
2. Run the following SQL to create tables:

```sql
-- Users table
CREATE TABLE root_users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Endpoints table
CREATE TABLE endpoints (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    root_user_id UUID REFERENCES root_users(id),
    name VARCHAR(100) NOT NULL,
    hostname VARCHAR(100) NOT NULL,
    ip_address INET,
    user_name VARCHAR(50) NOT NULL,
    os_info TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Blacklist table
CREATE TABLE blacklist (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    root_user_id UUID REFERENCES root_users(id),
    command VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Approval requests table
CREATE TABLE approval_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    endpoint_id UUID REFERENCES endpoints(id),
    user_name VARCHAR(50) NOT NULL,
    command VARCHAR(255) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## 📖 Usage

### Dashboard Access

1. **Login**: Visit `https://your-app.vercel.app`
2. **Register**: Create a new account
3. **Manage**: Add endpoints and configure blacklists

### Adding Endpoints

1. **Download installer**: Click "Download safe-cli-installer.sh"
2. **Run on endpoint**: `source ./safe-cli-installer.sh`
3. **Follow prompts**: Enter server URL and credentials
4. **Verify**: Check dashboard for new endpoint

### Managing Blacklists

1. **Navigate to Blacklist tab**
2. **Add commands**: One per line (e.g., `rm`, `sudo`, `fdisk`)
3. **Save changes**: Click "Save Changes"
4. **Update endpoints**: Run `source safe-cli-agent.sh` on endpoints

### Command Approval

1. **Monitor requests**: Check "Requests" tab
2. **Review details**: See command, user, and endpoint
3. **Approve/Deny**: Click appropriate button
4. **Auto-expiry**: Requests expire after 30 seconds

## 🔌 API Documentation

### Authentication Endpoints

#### `POST /api/auth/login`
Login with username and password.

**Request:**
```json
{
    "username": "admin",
    "password": "password123"
}
```

**Response:**
```json
{
    "success": true,
    "message": "Login successful",
    "user_id": "uuid",
    "username": "admin"
}
```

#### `POST /api/auth/register`
Register a new user account.

**Request:**
```json
{
    "username": "admin",
    "email": "admin@example.com",
    "password": "password123"
}
```

### Endpoint Management

#### `GET /api/endpoints`
Get all endpoints for the current user.

#### `POST /api/register_endpoint`
Register a new endpoint.

#### `POST /api/endpoints/{id}/activate`
Activate an endpoint.

#### `POST /api/endpoints/{id}/deactivate`
Deactivate an endpoint.

### Blacklist Management

#### `GET /api/blacklist`
Get current blacklist for the user.

#### `POST /api/blacklist`
Update the blacklist.

**Request:**
```json
{
    "blacklist": ["rm", "sudo", "fdisk", "mkfs"]
}
```

### Command Approval

#### `GET /api/requests`
Get pending approval requests.

#### `POST /api/approve/{id}`
Approve a command request.

#### `POST /api/deny/{id}`
Deny a command request.

## 🚀 Deployment

### Vercel Deployment

1. **Connect repository** to Vercel
2. **Set environment variables** in Vercel dashboard:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_KEY`: Your Supabase anon/public key
   - `SUPABASE_SERVICE_KEY`: Your Supabase service role key
3. **Deploy** automatically on push to main

**Live Demo**: [https://safe-cli.vercel.app/](https://safe-cli.vercel.app/)

### Docker Deployment

```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "server:app"]
```

### Manual Deployment

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export SUPABASE_URL="your-url"
export SUPABASE_KEY="your-key"
export FLASK_SECRET_KEY="your-secret"

# Run the application
python server.py
```

## 🛠️ Development

### Local Development

1. **Clone repository**
   ```bash
   git clone https://github.com/yourusername/safe-cli.git
   cd safe-cli
   ```

2. **Set up virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables**
   ```bash
   cp env_template_production.txt .env
   # Edit .env with your credentials
   ```

5. **Run development server**
   ```bash
   python server.py
   ```

### Project Structure

```
safe-cli/
├── server.py                 # Flask backend server
├── config.py                 # Configuration management
├── requirements.txt          # Python dependencies
├── vercel.json              # Vercel deployment config
├── frontend/                # Web dashboard
│   ├── index.html           # Main dashboard
│   ├── login.html           # Login page
│   ├── register.html        # Registration page
│   ├── app.js              # Frontend JavaScript
│   ├── styles.css          # CSS styles
│   ├── favicon.svg         # Favicon
│   └── manifest.json       # PWA manifest
├── safe-cli-installer.sh   # Endpoint installer
├── safe-cli-agent.sh       # Agent script
├── DEPLOYMENT.md           # Deployment guide
└── README.md              # This file
```

### Adding New Features

1. **Backend**: Add new routes in `server.py`
2. **Frontend**: Update `app.js` and HTML files
3. **Styling**: Modify `styles.css`
4. **Database**: Update Supabase schema if needed

### Testing

```bash
# Run the application
python server.py

# Test endpoints
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com","password":"test123"}'
```

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature-name`
3. **Make your changes**
4. **Test thoroughly**
5. **Commit changes**: `git commit -m "Add feature"`
6. **Push to branch**: `git push origin feature-name`
7. **Create Pull Request**

### Contribution Guidelines

- Follow existing code style
- Add tests for new features
- Update documentation
- Ensure all tests pass
- Be respectful and constructive

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check this README and `DEPLOYMENT.md`
- **Issues**: Report bugs on GitHub Issues
- **Discussions**: Use GitHub Discussions for questions
- **Email**: Contact the maintainers

## 🙏 Acknowledgments

- **Flask**: Web framework
- **Supabase**: Database and authentication
- **Vercel**: Hosting platform
- **Font Awesome**: Icons
- **Inter Font**: Typography

---

**Made with ❤️ for command-line security**

*Safe CLI - Protecting your systems, one command at a time.*
