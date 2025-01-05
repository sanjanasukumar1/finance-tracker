const express = require('express');
const bodyParser = require('body-parser');
const mysql = require('mysql2');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(bodyParser.json());

const db = mysql.createConnection({
  host: 'your-rds-endpoint',
  user: 'admin',
  password: 'your-db-password',
  database: 'finance'
});

app.get('/expenses', (req, res) => {
  db.query('SELECT * FROM expenses', (err, results) => {
    if (err) throw err;
    res.json(results);
  });
});

app.listen(5000, () => {
  console.log('Server running on port 5000');
});
