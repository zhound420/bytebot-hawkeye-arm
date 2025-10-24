import { Injectable, Logger } from '@nestjs/common';
import { OmniBoxClient } from './omnibox-client.service';
import {
  ComputerAction,
  ClickMouseAction,
  MoveMouseAction,
  TypeTextAction,
  PressKeysAction,
  ScrollAction,
  ApplicationAction,
} from '@bytebot/shared';

/**
 * Computer Use Service for Windows Desktop via OmniBox
 *
 * Provides bytebotd-compatible API for desktop control on Windows.
 * Translates Bytebot actions to PyAutoGUI commands executed via OmniBox.
 */
@Injectable()
export class ComputerUseService {
  private readonly logger = new Logger(ComputerUseService.name);

  constructor(private readonly omniboxClient: OmniBoxClient) {}

  /**
   * Execute computer action
   */
  async action(params: ComputerAction): Promise<any> {
    this.logger.log(`Executing action: ${params.action}`);

    switch (params.action) {
      case 'screenshot':
        return this.screenshot();

      case 'click_mouse':
        return this.clickMouse(params as ClickMouseAction);

      case 'move_mouse':
        return this.moveMouse(params as MoveMouseAction);

      case 'type_text':
        return this.typeText(params as TypeTextAction);

      case 'press_keys':
        return this.pressKeys(params as PressKeysAction);

      case 'scroll':
        return this.scroll(params as ScrollAction);

      case 'application':
        return this.launchApplication(params as ApplicationAction);

      case 'wait':
        return this.wait(params.duration || 500);

      case 'screen_info':
        return this.getScreenInfo();

      default:
        throw new Error(`Unsupported action: ${params.action}`);
    }
  }

  /**
   * Capture screenshot
   */
  async screenshot(): Promise<{ image: string }> {
    const buffer = await this.omniboxClient.screenshot();
    const base64 = buffer.toString('base64');

    return {
      image: base64,
    };
  }

  /**
   * Click mouse at coordinates
   */
  async clickMouse(params: ClickMouseAction): Promise<void> {
    const { coordinates, button = 'left', clickCount = 1 } = params;

    if (!coordinates) {
      throw new Error('Click coordinates required');
    }

    const { x, y } = coordinates;

    // Map button names
    const buttonMap: Record<string, string> = {
      left: 'left',
      right: 'right',
      middle: 'middle',
    };

    const pyButton = buttonMap[button] || 'left';

    // PyAutoGUI click command
    let pythonCode: string;

    if (clickCount === 2) {
      // Double click
      pythonCode = this.omniboxClient.buildPyAutoGUICommand('doubleClick', {
        x,
        y,
        button: pyButton,
      });
    } else {
      // Single or multiple clicks
      pythonCode = this.omniboxClient.buildPyAutoGUICommand('click', {
        x,
        y,
        clicks: clickCount,
        button: pyButton,
      });
    }

    await this.omniboxClient.execute(pythonCode);

    this.logger.debug(
      `Clicked at (${x}, ${y}) with ${button} button, count: ${clickCount}`,
    );
  }

  /**
   * Move mouse to coordinates
   */
  async moveMouse(params: MoveMouseAction): Promise<void> {
    const { coordinates } = params;

    if (!coordinates) {
      throw new Error('Move coordinates required');
    }

    const { x, y } = coordinates;

    const pythonCode = this.omniboxClient.buildPyAutoGUICommand('moveTo', {
      x,
      y,
      duration: 0.2, // Smooth movement
    });

    await this.omniboxClient.execute(pythonCode);

    this.logger.debug(`Moved mouse to (${x}, ${y})`);
  }

  /**
   * Type text
   */
  async typeText(params: TypeTextAction): Promise<void> {
    const { text } = params;

    if (!text) {
      throw new Error('Text required');
    }

    // Escape special characters for Python string
    const escapedText = text
      .replace(/\\/g, '\\\\')
      .replace(/'/g, "\\'")
      .replace(/"/g, '\\"')
      .replace(/\n/g, '\\n');

    const pythonCode = `import pyautogui; pyautogui.FAILSAFE = False; pyautogui.write('${escapedText}')`;

    await this.omniboxClient.execute(pythonCode);

    this.logger.debug(`Typed text: ${text.substring(0, 50)}...`);
  }

  /**
   * Press keyboard keys
   */
  async pressKeys(params: PressKeysAction): Promise<void> {
    const { keys } = params;

    if (!keys || keys.length === 0) {
      throw new Error('Keys required');
    }

    // Map keys to PyAutoGUI format
    const mappedKeys = keys.map((key) => this.mapKeyToPyAutoGUI(key));

    if (mappedKeys.length === 1) {
      // Single key press
      const pythonCode = this.omniboxClient.buildPyAutoGUICommand('press', {
        keys: mappedKeys[0],
      });
      await this.omniboxClient.execute(pythonCode);
    } else {
      // Hotkey combination
      const keysList = mappedKeys.map((k) => `'${k}'`).join(', ');
      const pythonCode = `import pyautogui; pyautogui.FAILSAFE = False; pyautogui.hotkey(${keysList})`;
      await this.omniboxClient.execute(pythonCode);
    }

    this.logger.debug(`Pressed keys: ${keys.join('+')}`);
  }

  /**
   * Scroll
   */
  async scroll(params: ScrollAction): Promise<void> {
    const { direction, scrollCount = 3 } = params;

    const scrollAmount = direction === 'up' ? scrollCount : -scrollCount;

    const pythonCode = this.omniboxClient.buildPyAutoGUICommand('scroll', {
      clicks: scrollAmount,
    });

    await this.omniboxClient.execute(pythonCode);

    this.logger.debug(`Scrolled ${direction} by ${scrollCount}`);
  }

  /**
   * Launch application via Start menu
   */
  async launchApplication(params: ApplicationAction): Promise<void> {
    const { application } = params;

    if (!application) {
      throw new Error('Application name required');
    }

    // Windows: Open Start menu, type app name, press Enter
    const pythonCode = `
import pyautogui
import time
pyautogui.FAILSAFE = False
# Open Start menu
pyautogui.press('win')
time.sleep(0.5)
# Type app name
pyautogui.write('${application.replace(/'/g, "\\'")}')
time.sleep(0.5)
# Press Enter
pyautogui.press('enter')
`;

    await this.omniboxClient.execute(pythonCode);

    this.logger.debug(`Launched application: ${application}`);
  }

  /**
   * Wait / delay
   */
  async wait(duration: number): Promise<void> {
    await new Promise((resolve) => setTimeout(resolve, duration));
    this.logger.debug(`Waited ${duration}ms`);
  }

  /**
   * Get screen information
   */
  async getScreenInfo(): Promise<{
    width: number;
    height: number;
    displaySize: { width: number; height: number };
  }> {
    // Windows default resolution (OmniBox uses 1920x1080 by default)
    // TODO: Query actual resolution from OmniBox
    const width = 1920;
    const height = 1080;

    return {
      width,
      height,
      displaySize: { width, height },
    };
  }

  /**
   * Map Bytebot key names to PyAutoGUI key names
   */
  private mapKeyToPyAutoGUI(key: string): string {
    const keyMap: Record<string, string> = {
      // Modifier keys
      ctrl: 'ctrl',
      alt: 'alt',
      shift: 'shift',
      win: 'win',
      super: 'win',
      meta: 'win',
      cmd: 'win',
      command: 'win',

      // Special keys
      enter: 'enter',
      return: 'enter',
      tab: 'tab',
      space: 'space',
      backspace: 'backspace',
      delete: 'delete',
      esc: 'esc',
      escape: 'esc',

      // Arrow keys
      up: 'up',
      down: 'down',
      left: 'left',
      right: 'right',

      // Function keys
      f1: 'f1',
      f2: 'f2',
      f3: 'f3',
      f4: 'f4',
      f5: 'f5',
      f6: 'f6',
      f7: 'f7',
      f8: 'f8',
      f9: 'f9',
      f10: 'f10',
      f11: 'f11',
      f12: 'f12',

      // Other keys
      home: 'home',
      end: 'end',
      pageup: 'pageup',
      pagedown: 'pagedown',
      insert: 'insert',
      printscreen: 'printscreen',

      // Numpad
      numlock: 'numlock',
      capslock: 'capslock',
      scrolllock: 'scrolllock',
    };

    const lowercaseKey = key.toLowerCase();
    return keyMap[lowercaseKey] || key;
  }
}
