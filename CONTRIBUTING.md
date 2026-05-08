# OEWA Contributing Guide

Thank you for your interest in contributing to OEWA!

## How to Contribute

### 1. Fork the Repository
Click the "Fork" button on the GitHub page to create your own copy of the repository.

### 2. Clone Your Fork
```bash
git clone https://github.com/YOUR_USERNAME/oewa.git
cd oewa
```

### 3. Create a Feature Branch
```bash
git checkout -b feature/your-feature-name
```

### 4. Make Your Changes
- Write clean, well-documented code
- Follow existing code style
- Add tests for new features
- Update documentation as needed

### 5. Commit Your Changes
```bash
git commit -m "Add: your feature description"
```

### 6. Push to Your Fork
```bash
git push origin feature/your-feature-name
```

### 7. Create a Pull Request
- Go to the original repository
- Click "New Pull Request"
- Select your branch
- Describe your changes in detail

## Contribution Types

### 🐛 Bug Reports
- Use GitHub Issues
- Include steps to reproduce
- Include expected vs actual behavior
- Include environment details

### 💡 Feature Requests
- Use GitHub Discussions
- Describe the use case
- Explain expected behavior
- Provide code examples (optional)

### 📖 Documentation
- Fix typos and improve clarity
- Add examples and tutorials
- Translate to other languages

### 🔧 Code Contributions
- Follow the code style guide
- Write unit tests
- Ensure all tests pass
- Update relevant documentation

## Development Setup

### Backend
```bash
cd OEWA-backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend
```bash
cd OEWA-frontend
npm install
npm run dev
```

### Running Tests
```bash
# Backend tests
cd OEWA-backend
pytest

# Frontend tests
cd OEWA-frontend
npm test
```

## Code Style

- Python: Follow PEP 8
- JavaScript/Vue: Follow ESLint config
- Commit messages: Use semantic versioning

## Questions?

- GitHub Discussions: https://github.com/oewa/oewa/discussions
- Email: support@oewa.com

---

Thank you for contributing to OEWA! 🚀