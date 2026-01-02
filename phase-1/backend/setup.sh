#!/bin/bash

# Backend setup and run script

set -e

echo "========================================="
echo "SQL Query Generator Backend Setup"
echo "========================================="

# Check if .env exists
if [ ! -f ../.env ]; then
    echo "Error: .env file not found in parent directory"
    echo "Please ensure .env is configured at phase-1/.env"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "========================================="
echo "Backend Setup Complete!"
echo "========================================="
echo ""
echo "To start the server:"
echo "1. cd backend"
echo "2. source venv/bin/activate"
echo "3. python main.py"
echo ""
echo "Or run: ./run.sh"
echo "========================================="
