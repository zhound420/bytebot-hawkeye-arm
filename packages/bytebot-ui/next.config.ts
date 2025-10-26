import type { NextConfig } from "next";
import dotenv from "dotenv";

dotenv.config();

const nextConfig: NextConfig = {
  transpilePackages: ["@bytebot/shared"],
  images: {
    remotePatterns: [],
    formats: ['image/avif', 'image/webp'],
    minimumCacheTTL: 60,
  },
  // Fix for custom server compatibility with React Server Components
  experimental: {
    // Ensure app directory works with custom server
    serverActions: {
      bodySizeLimit: '2mb',
    },
  },
  // Ensure proper webpack configuration for custom server
  webpack: (config, { isServer }) => {
    if (!isServer) {
      // Fix client-side module resolution for custom servers
      config.optimization = {
        ...config.optimization,
        splitChunks: {
          ...config.optimization?.splitChunks,
          cacheGroups: {
            ...config.optimization?.splitChunks?.cacheGroups,
            // Ensure framework code is properly chunked
            framework: {
              chunks: 'all',
              name: 'framework',
              test: /(?<!node_modules.*)[\\/]node_modules[\\/](react|react-dom|scheduler|prop-types|use-subscription)[\\/]/,
              priority: 40,
              enforce: true,
            },
          },
        },
      };
    }
    return config;
  },
};

export default nextConfig;
