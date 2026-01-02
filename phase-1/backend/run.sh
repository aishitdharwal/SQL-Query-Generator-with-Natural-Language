#!/bin/bash

# Run the FastAPI backend server

set -e

# Load environment from parent directory
export $(cat ../.env | grep -v '^#' | xargs)

# Activate virtual environment
source venv/bin/activate

# Run the server
echo "Starting FastAPI server on http://0.0.0.0:8080"
echo "API docs available at http://localhost:8080/docs"
echo ""
python main.py
