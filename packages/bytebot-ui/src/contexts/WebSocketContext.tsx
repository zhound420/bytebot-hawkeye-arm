"use client";

import React, { createContext, useContext, useEffect, useRef, useCallback, ReactNode } from "react";
import { io, Socket } from "socket.io-client";

interface WebSocketContextValue {
  socket: Socket | null;
  isConnected: boolean;
  joinTask: (taskId: string) => void;
  leaveTask: () => void;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  on: <T extends (...args: any[]) => void>(event: string, handler: T) => void;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  off: <T extends (...args: any[]) => void>(event: string, handler: T) => void;
}

const WebSocketContext = createContext<WebSocketContextValue | null>(null);

interface WebSocketProviderProps {
  children: ReactNode;
}

export function WebSocketProvider({ children }: WebSocketProviderProps) {
  const socketRef = useRef<Socket | null>(null);
  const currentTaskIdRef = useRef<string | null>(null);
  const [isConnected, setIsConnected] = React.useState(false);

  // Initialize WebSocket connection once
  useEffect(() => {
    if (socketRef.current?.connected) {
      return;
    }

    // Connect to the WebSocket server
    const socket = io({
      path: "/api/proxy/tasks",
      transports: ["websocket"],
      autoConnect: true,
      reconnection: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 1000,
    });

    socket.on("connect", () => {
      console.log("Connected to WebSocket server");
      setIsConnected(true);
    });

    socket.on("disconnect", () => {
      console.log("Disconnected from WebSocket server");
      setIsConnected(false);
    });

    socketRef.current = socket;

    // Cleanup on unmount
    return () => {
      if (socketRef.current) {
        socketRef.current.disconnect();
        socketRef.current = null;
      }
    };
  }, []);

  const joinTask = useCallback((taskId: string) => {
    const socket = socketRef.current;
    if (!socket) return;

    if (currentTaskIdRef.current) {
      socket.emit("leave_task", currentTaskIdRef.current);
    }
    socket.emit("join_task", taskId);
    currentTaskIdRef.current = taskId;
    console.log(`Joined task room: ${taskId}`);
  }, []);

  const leaveTask = useCallback(() => {
    const socket = socketRef.current;
    if (socket && currentTaskIdRef.current) {
      socket.emit("leave_task", currentTaskIdRef.current);
      console.log(`Left task room: ${currentTaskIdRef.current}`);
      currentTaskIdRef.current = null;
    }
  }, []);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const on = useCallback(<T extends (...args: any[]) => void>(event: string, handler: T) => {
    socketRef.current?.on(event, handler);
  }, []);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const off = useCallback(<T extends (...args: any[]) => void>(event: string, handler: T) => {
    socketRef.current?.off(event, handler);
  }, []);

  const value: WebSocketContextValue = {
    socket: socketRef.current,
    isConnected,
    joinTask,
    leaveTask,
    on,
    off,
  };

  return (
    <WebSocketContext.Provider value={value}>
      {children}
    </WebSocketContext.Provider>
  );
}

export function useWebSocketContext() {
  const context = useContext(WebSocketContext);
  if (!context) {
    throw new Error("useWebSocketContext must be used within a WebSocketProvider");
  }
  return context;
}
