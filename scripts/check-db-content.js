const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Path to the SQLite database
const dbPath = path.join(process.env.HOME, '.n8n', 'database.sqlite');

console.log('Connecting to n8n database:', dbPath);

// Open the database
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database:', err.message);
    return;
  }
  
  console.log('Connected to n8n database successfully');
  
  // Check if there are any users in the database
  db.all("SELECT * FROM users", (err, rows) => {
    if (err) {
      console.error('Error querying users table:', err.message);
    } else {
      console.log('\\nUsers in database:', rows.length);
      if (rows.length > 0) {
        rows.forEach(user => {
          console.log(`  - ID: ${user.id}, Email: ${user.email}, FirstName: ${user.firstName}, LastName: ${user.lastName}, Role: ${user.role}`);
        });
      } else {
        console.log('  No users found - this might explain the authentication issue');
      }
    }
    
    // Check the workflows table
    db.all("SELECT * FROM workflows", (err, rows) => {
      if (err) {
        console.error('Error querying workflows table:', err.message);
      } else {
        console.log('\\nWorkflows in database:', rows.length);
        if (rows.length > 0) {
          rows.forEach(wf => {
            console.log(`  - ID: ${wf.id}, Name: ${wf.name}, Active: ${wf.active}`);
          });
        } else {
          console.log('  No workflows found in database');
        }
      }
      
      // Close the database connection
      db.close((err) => {
        if (err) {
          console.error('Error closing database:', err.message);
        } else {
          console.log('\\nDatabase connection closed');
        }
      });
    });
  });
});