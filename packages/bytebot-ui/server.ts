import express from "express";
import { createProxyMiddleware } from "http-proxy-middleware";
import { createProxyServer } from "http-proxy";
import next from "next";
import { createServer, ServerResponse } from "http";
import dotenv from "dotenv";
import { Socket } from "net";
import http from "http";

// Load environment variables
dotenv.config();

const dev = process.env.NODE_ENV !== "production";
const hostname = process.env.HOSTNAME || "localhost";
const port = parseInt(process.env.PORT || "9992", 10);

// Backend URLs
const BYTEBOT_AGENT_BASE_URL = process.env.BYTEBOT_AGENT_BASE_URL;
const BYTEBOT_DESKTOP_LINUX_VNC_URL = process.env.BYTEBOT_DESKTOP_LINUX_VNC_URL || "http://bytebot-desktop:9990/websockify";
const BYTEBOT_DESKTOP_WINDOWS_VNC_URL = process.env.BYTEBOT_DESKTOP_WINDOWS_VNC_URL || "http://omnibox:8006/websockify";
// Backward compatibility - use legacy variable if new ones not set
const LEGACY_VNC_URL = process.env.BYTEBOT_DESKTOP_VNC_URL;

// Global variable to store detected desktop VNC URL
let DETECTED_DESKTOP_VNC_URL: string | null = null;

/**
 * Check if a desktop service is reachable
 */
async function checkDesktopAvailability(vncUrl: string): Promise<boolean> {
  return new Promise((resolve) => {
    try {
      const url = new URL(vncUrl);
      const options = {
        hostname: url.hostname,
        port: url.port || 80,
        path: "/",
        method: "GET",
        timeout: 2000, // 2 second timeout
      };

      const req = http.request(options, (res) => {
        // Any response means the service is up
        resolve(true);
      });

      req.on("error", () => {
        resolve(false);
      });

      req.on("timeout", () => {
        req.destroy();
        resolve(false);
      });

      req.end();
    } catch (err) {
      resolve(false);
    }
  });
}

/**
 * Auto-detect which desktop platform is available
 */
async function detectDesktopPlatform(): Promise<string> {
  console.log("Detecting available desktop platform...");

  // Check Linux desktop first (default)
  const linuxAvailable = await checkDesktopAvailability(BYTEBOT_DESKTOP_LINUX_VNC_URL);
  if (linuxAvailable) {
    console.log("✓ Linux desktop (bytebotd) detected");
    return BYTEBOT_DESKTOP_LINUX_VNC_URL;
  }

  // Check Windows desktop
  const windowsAvailable = await checkDesktopAvailability(BYTEBOT_DESKTOP_WINDOWS_VNC_URL);
  if (windowsAvailable) {
    console.log("✓ Windows desktop (OmniBox) detected");
    return BYTEBOT_DESKTOP_WINDOWS_VNC_URL;
  }

  // Fallback to legacy variable or Linux default
  if (LEGACY_VNC_URL) {
    console.log("⚠ No desktop detected, using legacy VNC URL:", LEGACY_VNC_URL);
    return LEGACY_VNC_URL;
  }

  console.log("⚠ No desktop detected, defaulting to Linux desktop");
  return BYTEBOT_DESKTOP_LINUX_VNC_URL;
}

// Initialize Next.js with custom server configuration
const app = next({
  dev,
  hostname,
  port,
  // Tell Next.js we're using a custom server (fixes RSC manifest issues)
  customServer: true,
});

app
  .prepare()
  .then(async () => {
    // Detect desktop platform at startup
    DETECTED_DESKTOP_VNC_URL = await detectDesktopPlatform();
    console.log("Using VNC URL:", DETECTED_DESKTOP_VNC_URL);

    const handle = app.getRequestHandler();
    const nextUpgradeHandler = app.getUpgradeHandler();

    const vncProxy = createProxyServer({ changeOrigin: true, ws: true });

    vncProxy.on("error", (err, req, res) => {
      console.error("Failed to proxy VNC request", {
        url: req.url,
        message: err.message,
      });

      if (!res) {
        return;
      }

      if (res instanceof ServerResponse) {
        if (!res.headersSent) {
          res.statusCode = 502;
          res.end("Bad Gateway");
        }
        return;
      }

      if (res instanceof Socket) {
        res.end();
      }
    });

    const expressApp = express();
    const server = createServer(expressApp);

    // WebSocket proxy for Socket.IO connections to backend
    const tasksProxy = createProxyMiddleware({
      target: BYTEBOT_AGENT_BASE_URL,
      ws: true,
      pathRewrite: { "^/api/proxy/tasks": "/socket.io" },
    });

    // Apply HTTP proxies
    expressApp.use("/api/proxy/tasks", tasksProxy);
    expressApp.use("/api/proxy/websockify", (req, res) => {
      console.log("Proxying websockify request");
      // Rewrite path using detected desktop URL
      const targetUrl = new URL(DETECTED_DESKTOP_VNC_URL!);
      req.url =
        targetUrl.pathname +
        (req.url?.replace(/^\/api\/proxy\/websockify/, "") || "");
      vncProxy.web(req, res, {
        target: `${targetUrl.protocol}//${targetUrl.host}`,
      });
    });

    // Handle all other requests with Next.js
    expressApp.all("*", (req, res) => handle(req, res));

    // Properly upgrade WebSocket connections
    server.on("upgrade", (request, socket, head) => {
      const { pathname } = new URL(
        request.url!,
        `http://${request.headers.host}`,
      );

      if (pathname.startsWith("/api/proxy/tasks")) {
        return tasksProxy.upgrade(request, socket as any, head);
      }

      if (pathname.startsWith("/api/proxy/websockify")) {
        const targetUrl = new URL(DETECTED_DESKTOP_VNC_URL!);
        request.url =
          targetUrl.pathname +
          (request.url?.replace(/^\/api\/proxy\/websockify/, "") || "");
        console.log("Proxying websockify upgrade request: ", request.url);
        return vncProxy.ws(request, socket as any, head, {
          target: `${targetUrl.protocol}//${targetUrl.host}`,
        });
      }

      nextUpgradeHandler(request, socket, head);
    });

    server.listen(port, hostname, () => {
      console.log(`> Ready on http://${hostname}:${port}`);
    });
  })
  .catch((err) => {
    console.error("Server failed to start:", err);
    process.exit(1);
  });
