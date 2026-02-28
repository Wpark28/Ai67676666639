#!/usr/bin/env python3
"""Simple HTTP server to serve the ErgAI web app locally."""
import http.server
import os

PORT = 8080
DIR = os.path.dirname(os.path.abspath(__file__))

os.chdir(DIR)

handler = http.server.SimpleHTTPServer if hasattr(http.server, 'SimpleHTTPServer') else http.server.SimpleHTTPRequestHandler

print(f"\n  ErgAI Web App running at:\n")
print(f"  http://localhost:{PORT}\n")
print(f"  Press Ctrl+C to stop\n")

with http.server.HTTPServer(("", PORT), http.server.SimpleHTTPRequestHandler) as httpd:
    httpd.serve_forever()
