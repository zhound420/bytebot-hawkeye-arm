"use client";

import { ReactNode } from "react";
import { WebSocketProvider } from "@/contexts/WebSocketContext";

interface ClientProvidersProps {
  children: ReactNode;
}

export function ClientProviders({ children }: ClientProvidersProps) {
  return <WebSocketProvider>{children}</WebSocketProvider>;
}
