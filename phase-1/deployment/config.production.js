// Production API Configuration
// Update this file for production deployment

const API_BASE_URL = window.location.origin;  // Use same origin as frontend

const API_ENDPOINTS = {
    LOGIN: `${API_BASE_URL}/api/login`,
    LOGOUT: `${API_BASE_URL}/api/logout`,
    SESSION: `${API_BASE_URL}/api/session`,
    SCHEMA: `${API_BASE_URL}/api/schema`,
    TABLES: `${API_BASE_URL}/api/tables`,
    TABLE: `${API_BASE_URL}/api/table`,
    GENERATE_SQL: `${API_BASE_URL}/api/generate-sql`,
    EXECUTE_QUERY: `${API_BASE_URL}/api/execute-query`,
    QUERY: `${API_BASE_URL}/api/query`,
};
