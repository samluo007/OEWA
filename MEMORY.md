# MEMORY.md - Long-term Memory

## 馃懁 User Profile

- **Name:** Sam Luo (samluo007@hotmail.com)
- **Identity:** CEO of recruiting company, building OEWA as a side project
- **GitHub:** samluo007 (2FA enabled)
- **Vibe:** Decisive, results-oriented CEO. Wants speed over perfection. "鏈€澶氬崐灏忔椂" style.
- **Timezone:** Asia/Shanghai (UTC+8)

## 馃 OEWA Project

**What:** OEWA = OpenClaw Enterprise Workflow Automation
**Goal:** AI Agent workflow automation platform for recruiters/RPO companies. Zero-code, YAML-based.
**URL:** https://samluo007.github.io/OEWA/ | https://github.com/samluo007/OEWA
**License:** MIT
**Revenue target:** 760 clients / 10.96M revenue / 50M valuation

### Architecture
- **Backend:** FastAPI + SQLite, port 8001 (http://localhost:8001)
- **Frontend:** Next.js/Tailwind, port 3000 (http://localhost:3000)
- **Deployed:** GitHub Pages (gh-pages branch), static build
- **GitHub:** https://github.com/samluo007/OEWA (clean branch)
- **6 templates:** data_report, ecommerce_cs, marketing_auto, recruitment, recruiter_outreach, xhs_xianyu_marketing

### Key Files
- `OEWA-backend/main.py` 鈥?FastAPI entry point, auto-loads YAML templates on startup
- `OEWA-backend/templates/` 鈥?YAML workflow templates
- `OEWA-frontend/src/App.vue` 鈥?Vue frontend (API_BASE=8001 after fix)
- `Launch-Pack-瀹屾暣鐗?md` 鈥?All promotion copy (LinkedIn, 鑴夎剦, emails, demo script)
- `demo-storyboard-20260509.md` 鈥?60-second demo video script
- `鍐峰鑱旈偖浠舵ā鏉?md` 鈥?Cold outreach email drafts

### GitHub Status (as of 2026-05-09)
- **clean branch:** Latest commit 086a8b2 (鍐峰鑱旈偖浠舵ā鏉?+ memory)
- **gh-pages branch:** Latest commit e913792 (Deploy v4, API_BASE=8001 fix)
- **Issues:** #1 (announcement), #2 (feature request)
- **Topics:** 12 tags (ai-agent, workflow-automation, recruitment, headhunter, rpo, etc.)
- **Labels:** announcement, featured, help wanted, good first issue, 鐚庡ご, workflow
- **CI:** GitHub Actions CI workflow added (ci.yml)
- **Discussions:** Enabled (API 404 for creating posts 鈥?known issue)

## 鈿狅笍 Key Constraints / Blockers

- **GitHub authentication:** Always requires PAT or user interaction for browser-based auth. 2FA blocks automated browser login.
- **GitHub Discussions:** API `GET /discussions/categories` returns 404 despite `has_discussions: true`. Can't create discussion posts via API yet.
- **LinkedIn/鑴夎剦 automation:** No public API. Browser automation blocked by SSRF policy. Manual posting required.
- **Product Hunt:** Needs account + manual submission.
- **Email sending:** No SMTP server available in current environment.
- **Windows encoding:** PowerShell `Set-Content` corrupts UTF-8. Use Node.js scripts or `Out-File -Encoding UTF8`.
- **Git push:** Long-running commands get SIGKILL. Use short timeouts + background sessions.

## 馃摑 Important Lessons

1. **GitHub PAT** is stored in `~/.git-credentials` and used by git automatically
2. **GitHub token ([GITHUB_PAT_REDACTED])** 鈥?can be used for GitHub REST API calls via PowerShell `Invoke-RestMethod`
3. **Deploy-new vs deploy-gh:** deploy-new = separate git repo for clean gh-pages force-push
4. **API_BASE fix:** Frontend originally pointed to port 8000, fixed to 8001 in App.vue
5. **GitHub token cleanup:** Never commit PAT tokens. Always clean before pushing.
6. **PowerShell `&&` operator:** Not supported in Windows PowerShell. Use `;` or background sessions.
7. **Git push timeout:** Long pushes (especially with large files) get killed. Use background sessions with polling.
8. **Node.js path:** Use full path `C:\Program Files\nodejs\node.exe` instead of just `node` in PowerShell.

## 馃殌 Commercialization Status (2026-05-09)

**What's done:**
- GitHub repo set up + Pages deployed
- 6 industry templates (2 headhunter-specific)
- Full promotion pack ready (LinkedIn, 鑴夎剦, demo video script, cold emails)
- GitHub Issues created for community engagement

**What user needs to do (manual):**
1. Post 鑴夎剦 (copy from Launch-Pack-瀹屾暣鐗?md) 鈥?2 min
2. Post LinkedIn (copy from Launch-Pack-瀹屾暣鐗?md) 鈥?5 min
3. Submit Product Hunt (https://www.producthunt.com) 鈥?10 min
4. Record demo video (Win+G, use demo-storyboard-20260509.md) 鈥?15 min
5. Star the GitHub repo + ask friends to star

**Promotion channels ranked by effort/impact:**
1. Product Hunt (high impact, requires account)
2. 鑴夎剦 (high relevance to target audience, manual)
3. GitHub Trending (free, needs community support)
4. LinkedIn (good for visibility, English audience)
5. V2EX/鎺橀噾 (developer community, Chinese)
