const fs = require('fs');
const path = require('path');

// Check if the n8n config file exists and what database it's using
const configPath = path.join(process.env.HOME, '.n8n/config');

if (fs.existsSync(configPath)) {
  console.log('n8n config file exists');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  console.log('Config contents:', config);
} else {
  console.log('n8n config file does not exist at ~/.n8n/config');
}

// Check if database file exists
const dbPath = path.join(process.env.HOME, '.n8n/database.sqlite');

if (fs.existsSync(dbPath)) {
  console.log('\\nDatabase file exists at:', dbPath);
  console.log('Database file size:', fs.statSync(dbPath).size, 'bytes');
} else {
  console.log('\\nDatabase file does not exist at:', dbPath);
}