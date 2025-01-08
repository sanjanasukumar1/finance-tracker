import React, { useState, useEffect } from 'react';
import axios from 'axios';

function App() {
  const [expenses, setExpenses] = useState([]);

  useEffect(() => {
    axios.get('http://finance-app-lb-1338696661.ap-south-1.elb.amazonaws.com/expenses')
      .then(response => setExpenses(response.data))
      .catch(error => console.error(error));
  }, []);

  return (
    <div className="App">
      <h1>Personal Finance Tracker</h1>
      <table>
        <thead>
          <tr>
            <th>Category</th>
            <th>Amount</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          {expenses.map(exp => (
            <tr key={exp.id}>
              <td>{exp.category}</td>
              <td>{exp.amount}</td>
              <td>{exp.date}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default App;
