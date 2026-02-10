const fs = require('fs');
const path = require('path');

// Read all workflow files
const workflowsDir = path.join(__dirname, '../workflows');
const workflowFiles = fs.readdirSync(workflowsDir);

console.log('Removing empty "options" properties from Switch nodes...\n');

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
          if (node.type.includes('switch') && 
              node.typeVersion === 3 && 
              node.parameters && 
              node.parameters.options !== undefined) {
            
            // Check if options object is empty or problematic
            const options = node.parameters.options;
            const isEmpty = typeof options === 'object' && 
                           options !== null && 
                           Object.keys(options).length === 0;
            
            if (isEmpty) {
              console.log(`Removing empty options from: ${file} -> ${node.name}`);
              delete node.parameters.options;
              modified = true;
            }
            // Note: We're keeping non-empty options objects as they serve a purpose
            // The issue mentioned in the documentation refers mainly to empty options
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

console.log('Empty "options" property removal completed.');