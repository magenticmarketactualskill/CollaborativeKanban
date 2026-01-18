const puppeteer = require('puppeteer');

async function takeScreenshots() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900 });

  const baseUrl = 'http://localhost:3001';

  try {
    // Log in first
    console.log('Logging in...');
    await page.goto(`${baseUrl}/login`, { waitUntil: 'networkidle0' });
    await page.type('input[type="email"]', 'demo@example.com');
    await page.click('input[type="submit"]');
    await page.waitForNavigation({ waitUntil: 'networkidle0' });

    // Go directly to My Tasks board (board 1) - Kanban view
    console.log('Taking screenshot: Kanban board...');
    await page.goto(`${baseUrl}/boards/1`, { waitUntil: 'networkidle0' });
    await new Promise(resolve => setTimeout(resolve, 1000)); // Wait for render
    await page.screenshot({ path: 'screenshots/03-kanban-board.png', fullPage: false });

    // Team board with members
    console.log('Taking screenshot: Team board...');
    await page.goto(`${baseUrl}/boards/2`, { waitUntil: 'networkidle0' });
    await new Promise(resolve => setTimeout(resolve, 1000));
    await page.screenshot({ path: 'screenshots/04-team-board.png', fullPage: false });

    // Board members page
    console.log('Taking screenshot: Board members...');
    await page.goto(`${baseUrl}/boards/2/board_members`, { waitUntil: 'networkidle0' });
    await new Promise(resolve => setTimeout(resolve, 500));
    await page.screenshot({ path: 'screenshots/05-board-members.png', fullPage: true });

    console.log('Additional screenshots taken successfully!');
  } catch (error) {
    console.error('Error taking screenshots:', error);
  } finally {
    await browser.close();
  }
}

takeScreenshots();
