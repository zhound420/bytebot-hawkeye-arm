'use client';

import { useState, useEffect } from 'react';
import { fetchApiKeyMetadata } from '@/utils/settingsUtils';

interface ApiKeyBannerProps {
  onOpenSettings?: () => void;
}

export function ApiKeyBanner({ onOpenSettings }: ApiKeyBannerProps) {
  const [showBanner, setShowBanner] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkApiKeys();
  }, []);

  const checkApiKeys = async () => {
    try {
      // Check if banner was dismissed recently
      const dismissedAt = localStorage.getItem('apiKeyBannerDismissed');
      if (dismissedAt) {
        const dismissedTime = parseInt(dismissedAt, 10);
        const now = Date.now();
        const hoursSinceDismissal = (now - dismissedTime) / (1000 * 60 * 60);

        // Re-show banner after 24 hours
        if (hoursSinceDismissal < 24) {
          setLoading(false);
          return;
        }
      }

      // Check if any API keys are configured
      const metadata = await fetchApiKeyMetadata();
      const hasAnyKey = Object.values(metadata).some((meta: any) => meta.configured);

      setShowBanner(!hasAnyKey);
    } catch (error) {
      console.error('Failed to check API key status:', error);
      // Show banner on error (better to show than hide)
      setShowBanner(true);
    } finally {
      setLoading(false);
    }
  };

  const handleDismiss = () => {
    localStorage.setItem('apiKeyBannerDismissed', Date.now().toString());
    setShowBanner(false);
  };

  const handleOpenSettings = () => {
    if (onOpenSettings) {
      onOpenSettings();
    }
    handleDismiss();
  };

  if (loading || !showBanner) {
    return null;
  }

  return (
    <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4 mb-4">
      <div className="flex items-start justify-between">
        <div className="flex items-start">
          <div className="flex-shrink-0">
            <svg
              className="h-5 w-5 text-yellow-400"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fillRule="evenodd"
                d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z"
                clipRule="evenodd"
              />
            </svg>
          </div>
          <div className="ml-3 flex-1">
            <h3 className="text-sm font-medium text-yellow-800">
              API Keys Required
            </h3>
            <div className="mt-2 text-sm text-yellow-700">
              <p>
                Configure at least one LLM API key in Settings to use AI features.
                Without API keys, the agent cannot function.
              </p>
            </div>
            <div className="mt-4">
              <div className="-mx-2 -my-1.5 flex">
                <button
                  type="button"
                  onClick={handleOpenSettings}
                  className="rounded-md bg-yellow-50 px-2 py-1.5 text-sm font-medium text-yellow-800 hover:bg-yellow-100 focus:outline-none focus:ring-2 focus:ring-yellow-600 focus:ring-offset-2 focus:ring-offset-yellow-50"
                >
                  Open Settings
                </button>
                <button
                  type="button"
                  onClick={handleDismiss}
                  className="ml-3 rounded-md bg-yellow-50 px-2 py-1.5 text-sm font-medium text-yellow-800 hover:bg-yellow-100 focus:outline-none focus:ring-2 focus:ring-yellow-600 focus:ring-offset-2 focus:ring-offset-yellow-50"
                >
                  Dismiss (24h)
                </button>
              </div>
            </div>
          </div>
        </div>
        <div className="ml-auto pl-3">
          <div className="-mx-1.5 -my-1.5">
            <button
              type="button"
              onClick={handleDismiss}
              className="inline-flex rounded-md bg-yellow-50 p-1.5 text-yellow-500 hover:bg-yellow-100 focus:outline-none focus:ring-2 focus:ring-yellow-600 focus:ring-offset-2 focus:ring-offset-yellow-50"
            >
              <span className="sr-only">Dismiss</span>
              <svg
                className="h-5 w-5"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fillRule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clipRule="evenodd"
                />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
