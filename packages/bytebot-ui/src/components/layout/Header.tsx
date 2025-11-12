import React, { useState, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";
import { useTheme } from "next-themes";

import { HugeiconsIcon } from "@hugeicons/react";
import {
  DocumentCodeIcon,
  TaskDaily01Icon,
  Home01Icon,
  ComputerIcon,
  Settings01Icon,
} from "@hugeicons/core-free-icons";
import { usePathname, useSearchParams } from "next/navigation";

import { Button } from "@/components/ui/button";
import { ApiKeySettingsDialog } from "@/components/settings/ApiKeySettingsDialog";
import { ThemeToggle } from "./ThemeToggle";
import { TrajectoryRecordingBadge } from "@/components/learning/TrajectoryRecordingBadge";
import { fetchApiKeyMetadata } from "@/utils/settingsUtils";

export function Header() {
  const { resolvedTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [hasApiKeys, setHasApiKeys] = useState(true); // Assume true initially
  const pathname = usePathname();
  const searchParams = useSearchParams();

  // After mounting, we can safely show the theme-dependent content
  useEffect(() => {
    setMounted(true);
  }, []);

  // Check API key status and auto-open on first visit
  useEffect(() => {
    const checkAndAutoOpen = async () => {
      try {
        // Check if any API keys are configured
        const metadata = await fetchApiKeyMetadata();
        const keysConfigured = Object.values(metadata).some((meta: any) => meta.configured);
        setHasApiKeys(keysConfigured);

        // Auto-open settings on first visit if no keys configured
        if (!keysConfigured) {
          const hasVisitedBefore = localStorage.getItem('bytebotHasVisited');
          const openSettingsParam = searchParams?.get('openSettings');

          if (!hasVisitedBefore || openSettingsParam === 'true') {
            // Small delay to avoid opening before component fully mounts
            setTimeout(() => {
              setSettingsOpen(true);
            }, 500);

            // Mark as visited
            localStorage.setItem('bytebotHasVisited', 'true');
          }
        }
      } catch (error) {
        console.error('Failed to check API key status:', error);
      }
    };

    if (mounted) {
      checkAndAutoOpen();
    }
  }, [mounted, searchParams]);

  // Function to determine if a link is active
  const isActive = (path: string) => {
    if (path === "/") {
      return pathname === "/";
    }
    return pathname?.startsWith(path);
  };

  // Get classes for navigation links based on active state
  const getLinkClasses = (path: string) => {
    const baseClasses =
      "flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background";
    const activeClasses =
      "bg-muted text-foreground shadow-sm dark:bg-muted dark:text-foreground";
    const inactiveClasses =
      "text-muted-foreground hover:bg-muted/80 hover:text-foreground dark:text-muted-foreground dark:hover:bg-muted/60";

    return `${baseClasses} ${
      isActive(path) ? activeClasses : inactiveClasses
    }`;
  };

  return (
    <header className="bg-background flex items-center justify-between border-b p-4">
      <div className="flex items-center gap-6">
        {/* Logo without link */}
        <div>
          {mounted ? (
            <Image
              src={
                resolvedTheme === "dark"
                  ? "/bytebot_transparent_logo_white.svg"
                  : "/bytebot_transparent_logo_dark.svg"
              }
              alt="Bytebot Logo"
              width={100}
              height={30}
              className="h-8 w-auto"
            />
          ) : (
            <div className="h-8 w-[110px]" />
          )}
        </div>
        <div className="h-5 border border-l-[0.5px] border-border/60 dark:border-border"></div>
        <div className="flex items-center gap-2">
          <Link href="/" className={getLinkClasses("/")}>
            <HugeiconsIcon icon={Home01Icon} className="h-4 w-4" />
            <span className="text-sm">Home</span>
          </Link>
          <Link href="/tasks" className={getLinkClasses("/tasks")}>
            <HugeiconsIcon icon={TaskDaily01Icon} className="h-4 w-4" />
            <span className="text-sm">Tasks</span>
          </Link>
          <Link href="/desktop" className={getLinkClasses("/desktop")}>
            <HugeiconsIcon icon={ComputerIcon} className="h-4 w-4" />
            <span className="text-sm">Desktop</span>
          </Link>
          <Link
            href="https://docs.bytebot.ai/quickstart"
            target="_blank"
            rel="noopener noreferrer"
            className={getLinkClasses("https://docs.bytebot.ai")}
          >
            <HugeiconsIcon icon={DocumentCodeIcon} className="h-4 w-4" />
            <span className="text-sm">Docs</span>
          </Link>
        </div>
      </div>
      <div className="flex items-center gap-3">
        <TrajectoryRecordingBadge />
        <ThemeToggle />
        <div className="relative">
          <Button
            type="button"
            variant="ghost"
            size="icon"
            onClick={() => setSettingsOpen(true)}
            aria-label="Open API key settings"
            title={!hasApiKeys ? "Configure API keys" : "Settings"}
          >
            <HugeiconsIcon icon={Settings01Icon} className="h-5 w-5" />
          </Button>
          {!hasApiKeys && (
            <span className="absolute -top-0.5 -right-0.5 flex h-3 w-3">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500"></span>
            </span>
          )}
        </div>
        <ApiKeySettingsDialog open={settingsOpen} onOpenChange={setSettingsOpen} />
      </div>
    </header>
  );
}
