const fs = require('fs');
const path = require('path');

// Read all workflow files
const workflowsDir = path.join(__dirname, '../workflows');
const workflowFiles = fs.readdirSync(workflowsDir);

console.log('Identifying Switch nodes with "options" property...\n');

for (const file of workflowFiles) {
  if (file.endsWith('.json')) {
    try {
      const filePath = path.join(workflowsDir, file);
      const content = fs.readFileSync(filePath, 'utf8');
      
      // Handle potential control characters in JSON
      const cleanContent = content.replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
      const workflow = JSON.parse(cleanContent);
      
      if (workflow.nodes) {
        for (const node of workflow.nodes) {
          if (node.type.includes('switch') && node.typeVersion === 3 && node.parameters && node.parameters.options) {
            console.log(`File: ${file}`);
            console.log(`  Node: ${node.name}`);
            console.log(`  Options:`, node.parameters.options);
            console.log('');
          }
        }
      }
    } catch (error) {
      console.error(`❌ Error parsing ${file}:`, error.message);
    }
  }
}