#!/usr/bin/env python
import SimpleHTTPServer

class MyHTTPRequestHandler(SimpleHTTPServer.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_my_headers()

        SimpleHTTPServer.SimpleHTTPRequestHandler.end_headers(self)

    def send_my_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")


if __name__ == '__main__':
    SimpleHTTPServer.test(HandlerClass=MyHTTPRequestHandler)
