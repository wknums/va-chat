"""
Simple HTTP server to serve the sample site files for testing
"""
import http.server
import socketserver
import os
from pathlib import Path

PORT = 9000
DIRECTORY = Path(__file__).parent.parent / "sample-site"

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIRECTORY), **kwargs)
    
    def end_headers(self):
        # Add CORS headers for local development
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

def main():
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"✓ Serving Sample site files at http://localhost:{PORT}")
        print(f"  Directory: {DIRECTORY}")
        print(f"\n📋 Test URLs:")
        print(f"  • Test Page: http://localhost:{PORT}/test-chat-widget.html")
        print(f"  • Home Page: http://localhost:{PORT}/index.html")
        print(f"  • Services: http://localhost:{PORT}/services.html")
        print(f"\n💡 Make sure FastAPI is running on http://localhost:8080")
        print(f"\nPress Ctrl+C to stop the server\n")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n✓ Server stopped")

if __name__ == "__main__":
    main()
