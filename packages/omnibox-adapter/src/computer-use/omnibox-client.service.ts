import { Injectable, Logger } from '@nestjs/common';

/**
 * Client for OmniBox Computer Use API
 *
 * Communicates with the Windows 11 VM's HTTP API on port 5000
 * to execute desktop control actions via PyAutoGUI.
 */
@Injectable()
export class OmniBoxClient {
  private readonly logger = new Logger(OmniBoxClient.name);
  private readonly baseUrl: string;
  private readonly timeout: number;

  constructor() {
    this.baseUrl = process.env.OMNIBOX_URL || 'http://omnibox:5000';
    this.timeout = parseInt(process.env.OMNIBOX_TIMEOUT || '30000', 10);

    this.logger.log(`OmniBoxClient initialized: ${this.baseUrl}`);
  }

  /**
   * Execute Python command via PyAutoGUI
   */
  async execute(pythonCode: string): Promise<void> {
    const startTime = Date.now();

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);

      const response = await fetch(`${this.baseUrl}/execute`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          command: ['python', '-c', pythonCode],
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(
          `OmniBox execute failed: ${response.status} ${errorText}`,
        );
      }

      // Check Python execution result
      const result = await response.json();

      // Check for execution errors
      if (result.status === 'error') {
        throw new Error(`Python execution error: ${result.message}`);
      }

      // Check return code
      if (result.returncode !== 0) {
        const stderr = result.error?.trim() || '(no error output)';
        throw new Error(
          `Python command failed with exit code ${result.returncode}: ${stderr}`,
        );
      }

      // Log stderr warnings even on success (returncode 0)
      if (result.error && result.error.trim().length > 0) {
        this.logger.warn(`Python stderr: ${result.error.trim()}`);
      }

      const elapsed = Date.now() - startTime;
      this.logger.debug(`Executed command in ${elapsed}ms`);
    } catch (error) {
      const elapsed = Date.now() - startTime;
      this.logger.error(
        `OmniBox execute error after ${elapsed}ms: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Capture screenshot from Windows desktop
   */
  async screenshot(): Promise<Buffer> {
    const startTime = Date.now();

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);

      const response = await fetch(`${this.baseUrl}/screenshot`, {
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(
          `OmniBox screenshot failed: ${response.status} ${response.statusText}`,
        );
      }

      const buffer = Buffer.from(await response.arrayBuffer());
      const elapsed = Date.now() - startTime;

      this.logger.debug(
        `Captured screenshot in ${elapsed}ms (${buffer.length} bytes)`,
      );

      return buffer;
    } catch (error) {
      const elapsed = Date.now() - startTime;
      this.logger.error(
        `OmniBox screenshot error after ${elapsed}ms: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Check if OmniBox API is available
   */
  async checkHealth(): Promise<boolean> {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);

      const response = await fetch(`${this.baseUrl}/health`, {
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      return response.ok;
    } catch (error) {
      this.logger.debug(`Health check failed: ${error.message}`);
      return false;
    }
  }

  /**
   * Get cursor position
   */
  async getCursorPosition(): Promise<{ x: number; y: number }> {
    const pythonCode = `
import pyautogui
import json
pos = pyautogui.position()
print(json.dumps({"x": pos.x, "y": pos.y}))
`;

    const startTime = Date.now();

    try {
      const controller = new AbortController();
      const timeout = parseInt(process.env.OMNIBOX_TIMEOUT || '30000', 10);
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      const baseUrl = process.env.OMNIBOX_URL || 'http://omnibox:5000';
      const response = await fetch(`${baseUrl}/execute`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          command: ['python', '-c', pythonCode],
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(
          `OmniBox execute failed: ${response.status} ${errorText}`,
        );
      }

      const result = await response.json();
      const elapsed = Date.now() - startTime;

      this.logger.debug(`Got cursor position in ${elapsed}ms`);

      // Check for errors
      if (result.status === 'error') {
        throw new Error(`Python execution error: ${result.message}`);
      }

      if (result.returncode !== 0) {
        throw new Error(
          `Python command failed with code ${result.returncode}: ${result.error}`,
        );
      }

      // Parse JSON from output
      const position = JSON.parse(result.output.trim());
      return { x: position.x, y: position.y };
    } catch (error) {
      const elapsed = Date.now() - startTime;
      this.logger.error(
        `OmniBox getCursorPosition error after ${elapsed}ms: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Get Windows setup progress status
   */
  async getSetupStatus(): Promise<any> {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);

      const response = await fetch(`${this.baseUrl}/setup/status`, {
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(
          `OmniBox setup status failed: ${response.status} ${response.statusText}`,
        );
      }

      return await response.json();
    } catch (error) {
      this.logger.debug(`Setup status check failed: ${error.message}`);
      // Return default status if endpoint not available
      return {
        stage: 'Unknown',
        details: 'Status endpoint not available',
        progress: 0,
        total: 9,
        percent: 0.0,
        elapsed_seconds: 0,
        is_complete: false,
      };
    }
  }

  /**
   * Helper: Build PyAutoGUI command
   */
  buildPyAutoGUICommand(action: string, args: Record<string, any> = {}): string {
    const argsList = Object.entries(args)
      .map(([key, value]) => {
        if (typeof value === 'string') {
          return `${key}='${value.replace(/'/g, "\\'")}'`;
        }
        return `${key}=${JSON.stringify(value)}`;
      })
      .join(', ');

    return `import pyautogui; pyautogui.FAILSAFE = False; pyautogui.${action}(${argsList})`;
  }
}
