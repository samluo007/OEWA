# Contributing to OEWA

OEWA = OpenClaw Enterprise Workflow Automation

AI Agent workflow automation platform for recruiters and RPO companies. Configure workflows with YAML, run with zero code.

## Ways to Contribute

### ⭐ Star the Repository
Simplest way to support OEWA!

### 🐛 Report Bugs
Create a [GitHub Issue](https://github.com/samluo007/OEWA/issues) with label ug.

### 💡 Suggest Features
Comment on [Issue #2](https://github.com/samluo007/OEWA/issues/2) or create a new issue with label enhancement.

### 📝 Contribute Workflow Templates
Core of OEWA is YAML workflow templates in OEWA-backend/templates/. Contributions welcome!

### 🔧 Fix Code
1. Fork the repo
2. Create branch: git checkout -b fix/your-fix-name
3. Commit: git commit -m 'fix: ...'
4. Push: git push origin fix/your-fix-name
5. Open Pull Request

## Development Setup

\\\ash
git clone https://github.com/samluo007/OEWA.git
cd OEWA/OEWA-backend
pip install -r requirements.txt
python main.py
# Visit http://localhost:8001
\\\

## Project Structure

\\\
OEWA/
├── OEWA-backend/       # FastAPI backend
│   ├── main.py         # Entry point
│   ├── executor.py     # Workflow engine
│   └── templates/      # YAML workflow templates
│       ├── recruitment.yaml
│       └── recruiter_outreach.yaml
├── OEWA-frontend/      # Vue frontend
└── OEWA-docs/          # Documentation
\\\

## License

MIT License
