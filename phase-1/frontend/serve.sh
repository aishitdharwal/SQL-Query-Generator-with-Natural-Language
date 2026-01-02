#!/bin/bash

# Frontend server script using Python's built-in HTTP server

echo "========================================="
echo "Starting Frontend Server"
echo "========================================="
echo ""
echo "Server running at: http://localhost:3000"
echo "Press Ctrl+C to stop"
echo ""

# Start Python HTTP server
python3 -m http.server 3000
