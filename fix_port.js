const fs = require('fs');
const path = require('path');

const file = 'OEWA-backend/main.py';
const fullPath = path.join(process.cwd(), file);

console.log('Full path:', fullPath);
console.log('Exists:', fs.existsSync(fullPath));

const content = fs.readFileSync(fullPath, 'utf8');
console.log('File length:', content.length);

// Find port line
const lines = content.split('\n');
lines.forEach((line, i) => {
  if (line.includes('port=')) {
    console.log('Found at line ' + (i+1) + ':', line.trim());
  }
});

// Replace port=8000 with port=8001
const newContent = content.replace(/port=8000/, 'port=8001');
console.log('Replacement done, new length:', newContent.length);

// Verify
if (newContent.includes('port=8001')) {
  console.log('Port 8001 found - writing file');
  fs.writeFileSync(fullPath, newContent, 'utf8');
  console.log('File written successfully');
} else {
  console.log('ERROR: port=8001 not found after replacement!');
}
