"use client";

import dynamic from 'next/dynamic';

// Disable SSR for this page to prevent WebSocket initialization errors
// during server-side rendering. This fixes React Client Manifest errors.
const TaskPageClient = dynamic(() => import('./TaskPageClient'), {
  ssr: false,
  loading: () => (
    <div className="flex h-screen items-center justify-center">
      <div className="text-center">
        <div className="mb-2 text-sm text-muted-foreground">Loading task...</div>
      </div>
    </div>
  ),
});

export default TaskPageClient;
