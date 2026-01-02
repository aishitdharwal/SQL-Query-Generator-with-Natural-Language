// Dashboard functionality
let currentSession = null;
let schemaData = null;
let currentSQL = null;

document.addEventListener('DOMContentLoaded', () => {
    // Check authentication
    checkAuth();
    
    // Setup event listeners
    setupEventListeners();
});

async function checkAuth() {
    try {
        const response = await fetch(API_ENDPOINTS.SESSION, {
            credentials: 'include',
        });
        
        if (!response.ok) {
            // Not authenticated, redirect to login
            window.location.href = 'index.html';
            return;
        }
        
        const data = await response.json();
        currentSession = data;
        
        // Update UI with user info
        document.getElementById('teamName').textContent = data.team.toUpperCase();
        document.getElementById('username').textContent = data.username;
        
        // Load schema
        loadSchema();
        
    } catch (error) {
        console.error('Auth check failed:', error);
        window.location.href = 'index.html';
    }
}

function setupEventListeners() {
    // Logout button
    document.getElementById('logoutBtn').addEventListener('click', logout);
    
    // Query buttons
    document.getElementById('generateBtn').addEventListener('click', generateSQL);
    document.getElementById('executeBtn').addEventListener('click', generateAndExecute);
    
    // SQL action buttons
    document.getElementById('runSQLBtn').addEventListener('click', executeGeneratedSQL);
    document.getElementById('editSQLBtn').addEventListener('click', showEditSQL);
    document.getElementById('copySQLBtn').addEventListener('click', copySQL);
    
    // Edit SQL buttons
    document.getElementById('runEditedSQLBtn').addEventListener('click', executeEditedSQL);
    document.getElementById('cancelEditBtn').addEventListener('click', cancelEdit);
    
    // Enter key in natural query textarea
    document.getElementById('naturalQuery').addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
            e.preventDefault();
            generateSQL();
        }
    });
}

async function logout() {
    try {
        await fetch(API_ENDPOINTS.LOGOUT, {
            method: 'POST',
            credentials: 'include',
        });
    } catch (error) {
        console.error('Logout error:', error);
    } finally {
        window.location.href = 'index.html';
    }
}

async function loadSchema() {
    const schemaLoading = document.getElementById('schemaLoading');
    const schemaContent = document.getElementById('schemaContent');
    const tablesList = document.getElementById('tablesList');
    
    try {
        const response = await fetch(API_ENDPOINTS.SCHEMA, {
            credentials: 'include',
        });
        
        if (!response.ok) {
            throw new Error('Failed to load schema');
        }
        
        const data = await response.json();
        schemaData = data.schema;
        
        // Hide loading, show content
        schemaLoading.style.display = 'none';
        schemaContent.style.display = 'block';
        
        // Render tables
        tablesList.innerHTML = '';
        Object.keys(schemaData).forEach(tableName => {
            const tableItem = createTableItem(tableName, schemaData[tableName]);
            tablesList.appendChild(tableItem);
        });
        
    } catch (error) {
        schemaLoading.textContent = 'Failed to load schema';
        console.error('Schema load error:', error);
    }
}

function createTableItem(tableName, tableInfo) {
    const div = document.createElement('div');
    div.className = 'table-item';
    
    const nameDiv = document.createElement('div');
    nameDiv.className = 'table-name';
    nameDiv.textContent = tableName;
    
    const columnsDiv = document.createElement('div');
    columnsDiv.className = 'table-columns';
    columnsDiv.textContent = `${tableInfo.columns.length} columns`;
    
    div.appendChild(nameDiv);
    div.appendChild(columnsDiv);
    
    div.addEventListener('click', () => showTableDetails(tableName));
    
    return div;
}

async function showTableDetails(tableName) {
    try {
        const response = await fetch(`${API_ENDPOINTS.TABLE}/${tableName}`, {
            credentials: 'include',
        });
        
        if (!response.ok) {
            throw new Error('Failed to load table details');
        }
        
        const data = await response.json();
        
        // Show table details in a simple alert for now
        const columns = data.schema.columns.map(col => 
            `${col.column_name} (${col.data_type})`
        ).join('\n');
        
        alert(`Table: ${tableName}\n\nColumns:\n${columns}`);
        
    } catch (error) {
        console.error('Table details error:', error);
        alert('Failed to load table details');
    }
}

async function generateSQL() {
    const naturalQuery = document.getElementById('naturalQuery').value.trim();
    
    if (!naturalQuery) {
        alert('Please enter a question');
        return;
    }
    
    const generateBtn = document.getElementById('generateBtn');
    generateBtn.disabled = true;
    generateBtn.textContent = 'Generating...';
    
    // Hide previous results/errors
    hideSection('resultsSection');
    hideSection('errorSection');
    hideSection('sqlEditSection');
    
    try {
        const response = await fetch(API_ENDPOINTS.GENERATE_SQL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            credentials: 'include',
            body: JSON.stringify({ natural_query: naturalQuery }),
        });
        
        const data = await response.json();
        
        if (response.ok && data.success) {
            currentSQL = data.sql_query;
            
            // Show SQL section
            document.getElementById('generatedSQL').textContent = data.sql_query;
            showSection('sqlSection');
            
        } else {
            showError(data.error || 'Failed to generate SQL');
        }
        
    } catch (error) {
        showError('Network error. Please try again.');
        console.error('Generate SQL error:', error);
    } finally {
        generateBtn.disabled = false;
        generateBtn.textContent = 'Generate SQL';
    }
}

async function generateAndExecute() {
    const naturalQuery = document.getElementById('naturalQuery').value.trim();
    
    if (!naturalQuery) {
        alert('Please enter a question');
        return;
    }
    
    const executeBtn = document.getElementById('executeBtn');
    executeBtn.disabled = true;
    executeBtn.textContent = 'Processing...';
    
    // Hide previous sections
    hideSection('sqlSection');
    hideSection('resultsSection');
    hideSection('errorSection');
    hideSection('sqlEditSection');
    
    try {
        const response = await fetch(API_ENDPOINTS.QUERY, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            credentials: 'include',
            body: JSON.stringify({ natural_query: naturalQuery }),
        });
        
        const data = await response.json();
        
        if (response.ok && data.success) {
            currentSQL = data.sql_query;
            
            // Show SQL
            document.getElementById('generatedSQL').textContent = data.sql_query;
            showSection('sqlSection');
            
            // Show results
            displayResults(data);
            
        } else {
            // Show SQL if it was generated
            if (data.sql_query) {
                currentSQL = data.sql_query;
                document.getElementById('generatedSQL').textContent = data.sql_query;
                showSection('sqlSection');
            }
            
            showError(data.error || 'Query execution failed');
        }
        
    } catch (error) {
        showError('Network error. Please try again.');
        console.error('Execute query error:', error);
    } finally {
        executeBtn.disabled = false;
        executeBtn.textContent = 'Generate & Execute';
    }
}

async function executeGeneratedSQL() {
    if (!currentSQL) {
        alert('No SQL query to execute');
        return;
    }
    
    const runBtn = document.getElementById('runSQLBtn');
    runBtn.disabled = true;
    runBtn.textContent = 'Running...';
    
    hideSection('resultsSection');
    hideSection('errorSection');
    
    try {
        const response = await fetch(API_ENDPOINTS.EXECUTE_QUERY, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            credentials: 'include',
            body: JSON.stringify({ sql_query: currentSQL }),
        });
        
        const data = await response.json();
        
        if (data.success) {
            displayResults(data);
        } else {
            showError(data.error || 'Query execution failed');
        }
        
    } catch (error) {
        showError('Network error. Please try again.');
        console.error('Execute SQL error:', error);
    } finally {
        runBtn.disabled = false;
        runBtn.textContent = 'Run Query';
    }
}

async function executeEditedSQL() {
    const editedSQL = document.getElementById('editableSQL').value.trim();
    
    if (!editedSQL) {
        alert('Please enter a SQL query');
        return;
    }
    
    const runBtn = document.getElementById('runEditedSQLBtn');
    runBtn.disabled = true;
    runBtn.textContent = 'Running...';
    
    hideSection('resultsSection');
    hideSection('errorSection');
    
    try {
        const response = await fetch(API_ENDPOINTS.EXECUTE_QUERY, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            credentials: 'include',
            body: JSON.stringify({ sql_query: editedSQL }),
        });
        
        const data = await response.json();
        
        if (data.success) {
            // Update current SQL and display
            currentSQL = editedSQL;
            document.getElementById('generatedSQL').textContent = editedSQL;
            
            // Hide edit section, show SQL section
            hideSection('sqlEditSection');
            showSection('sqlSection');
            
            displayResults(data);
        } else {
            showError(data.error || 'Query execution failed');
        }
        
    } catch (error) {
        showError('Network error. Please try again.');
        console.error('Execute edited SQL error:', error);
    } finally {
        runBtn.disabled = false;
        runBtn.textContent = 'Run Edited Query';
    }
}

function displayResults(data) {
    const resultsTable = document.getElementById('resultsTable');
    const rowCount = document.getElementById('rowCount');
    
    if (!data.rows || data.rows.length === 0) {
        resultsTable.innerHTML = '<p class="loading">No results found</p>';
        rowCount.textContent = '0 rows';
        showSection('resultsSection');
        return;
    }
    
    // Create table
    const table = document.createElement('table');
    table.className = 'results-table';
    
    // Create header
    const thead = document.createElement('thead');
    const headerRow = document.createElement('tr');
    
    data.columns.forEach(col => {
        const th = document.createElement('th');
        th.textContent = col;
        headerRow.appendChild(th);
    });
    
    thead.appendChild(headerRow);
    table.appendChild(thead);
    
    // Create body
    const tbody = document.createElement('tbody');
    
    data.rows.forEach(row => {
        const tr = document.createElement('tr');
        
        data.columns.forEach(col => {
            const td = document.createElement('td');
            const value = row[col];
            td.textContent = value !== null && value !== undefined ? value : 'NULL';
            tr.appendChild(td);
        });
        
        tbody.appendChild(tr);
    });
    
    table.appendChild(tbody);
    
    resultsTable.innerHTML = '';
    resultsTable.appendChild(table);
    
    rowCount.textContent = `${data.rows.length} row${data.rows.length !== 1 ? 's' : ''}`;
    
    showSection('resultsSection');
}

function showEditSQL() {
    document.getElementById('editableSQL').value = currentSQL;
    hideSection('sqlSection');
    showSection('sqlEditSection');
}

function cancelEdit() {
    hideSection('sqlEditSection');
    showSection('sqlSection');
}

function copySQL() {
    if (!currentSQL) return;
    
    navigator.clipboard.writeText(currentSQL).then(() => {
        const btn = document.getElementById('copySQLBtn');
        const originalText = btn.textContent;
        btn.textContent = '✓';
        setTimeout(() => {
            btn.textContent = originalText;
        }, 2000);
    }).catch(err => {
        console.error('Copy failed:', err);
        alert('Failed to copy SQL');
    });
}

function showError(message) {
    document.getElementById('errorContent').textContent = message;
    showSection('errorSection');
}

function showSection(sectionId) {
    document.getElementById(sectionId).style.display = 'block';
}

function hideSection(sectionId) {
    document.getElementById(sectionId).style.display = 'none';
}
