const fs = require('fs');
const path = require('path');

// Read all workflow files
const workflowsDir = path.join(__dirname, '../workflows');
const workflowFiles = fs.readdirSync(workflowsDir);

console.log('Updating Postgres queries to use parameterized syntax...\n');

// Define mapping of risky queries to safer parameterized versions
const queryUpdates = {
  'BB_02_Security_Firewall.json': {
    'DB: Check User': {
      oldQuery: "SELECT * FROM users WHERE telegram_id = {{ $node['Guard: Input Schema'].json.user.telegram_id }}::bigint",
      newQuery: "SELECT * FROM users WHERE telegram_id = $1",
      newParameters: "{{ $node['Guard: Input Schema'].json.user.telegram_id }}"
    }
  },
  'BB_09_Deep_Link_Redirect.json': {
    'DB: Get Bot Config': {
      oldQuery: "SELECT value FROM public.app_config WHERE key = 'TELEGRAM_BOT_USERNAME' LIMIT 1",
      newQuery: "SELECT value FROM public.app_config WHERE key = $1 LIMIT 1",
      newParameters: "TELEGRAM_BOT_USERNAME"
    }
  }
  // Note: Other queries like SELECT * or function calls can't be easily parameterized
  // without knowing the specific use case and parameters needed
};

for (const file of workflowFiles) {
  if (file.endsWith('.json')) {
    try {
      const filePath = path.join(workflowsDir, file);
      const content = fs.readFileSync(filePath, 'utf8');
      
      // Handle potential control characters in JSON
      const cleanContent = content.replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
      const workflow = JSON.parse(cleanContent);
      
      let modified = false;
      
      if (workflow.nodes) {
        for (const node of workflow.nodes) {
          if ((node.type.includes('postgres') || node.type.includes('postgresdb')) && 
              node.parameters && 
              node.parameters.operation === 'executeQuery') {
            
            const nodeName = node.name;
            if (queryUpdates[file] && queryUpdates[file][nodeName]) {
              const updateInfo = queryUpdates[file][nodeName];
              
              if (node.parameters.query === updateInfo.oldQuery) {
                console.log(`Updating query in: ${file} -> ${nodeName}`);
                console.log(`  Old: ${updateInfo.oldQuery}`);
                console.log(`  New: ${updateInfo.newQuery}`);
                
                node.parameters.query = updateInfo.newQuery;
                
                // Add query parameters if specified
                if (updateInfo.newParameters) {
                  node.parameters.queryParameters = updateInfo.newParameters;
                }
                
                modified = true;
                console.log('');
              }
            }
          }
        }
      }
      
      // Write back the file if modified
      if (modified) {
        fs.writeFileSync(filePath, JSON.stringify(workflow, null, 2));
        console.log(`Updated: ${file}\n`);
      }
    } catch (error) {
      console.error(`❌ Error processing ${file}:`, error.message);
    }
  }
}

console.log('SQL injection risk mitigation completed for identified cases.');
console.log('\\nNote: Some queries like SELECT statements with hardcoded values or function calls');
console.log('were not modified as they require specific business logic to determine proper parameters.');