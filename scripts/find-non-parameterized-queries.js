const fs = require('fs');
const path = require('path');

// Read all workflow files
const workflowsDir = path.join(__dirname, '../workflows');
const workflowFiles = fs.readdirSync(workflowsDir);

console.log('Identifying Postgres nodes with potential SQL injection risks...\n');

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
          if ((node.type.includes('postgres') || node.type.includes('postgresdb')) && 
              node.parameters && 
              node.parameters.operation === 'executeQuery') {
            
            const query = node.parameters.query;
            if (typeof query === 'string') {
              // Check if query uses parameterized syntax ($1, $2, etc.)
              const hasParameterizedSyntax = /\$[0-9]+/.test(query);
              
              if (!hasParameterizedSyntax) {
                console.log(`File: ${file}`);
                console.log(`  Node: ${node.name}`);
                console.log(`  Query: ${query.substring(0, 100)}${query.length > 100 ? '...' : ''}`);
                console.log(`  Parameterized: ${hasParameterizedSyntax ? 'YES' : 'NO - POTENTIAL RISK'}`);
                console.log('');
              }
            }
          }
        }
      }
    } catch (error) {
      console.error(`❌ Error parsing ${file}:`, error.message);
    }
  }
}