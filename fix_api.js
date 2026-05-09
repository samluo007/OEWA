const fs = require('fs');
const path = require('path');

const file = path.join(process.cwd(), 'OEWA-frontend', 'src', 'App.vue');
const content = fs.readFileSync(file, 'utf8');

// Fix port 8000 → 8001
const fixed = content.replace(/localhost:8000/g, 'localhost:8001');
fs.writeFileSync(file, fixed, 'utf8');
console.log('Fixed API_BASE in App.vue');