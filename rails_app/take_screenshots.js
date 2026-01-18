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
    // 1. Login page
    console.log('Taking screenshot: Login page...');
    await page.goto(`${baseUrl}/login`, { waitUntil: 'networkidle0' });
    await page.screenshot({ path: 'screenshots/01-login.png', fullPage: false });

    // 2. Log in
    console.log('Logging in...');
    await page.type('input[type="email"]', 'demo@example.com');
    await page.click('input[type="submit"]');
    await page.waitForNavigation({ waitUntil: 'networkidle0' });

    // 3. Boards list
    console.log('Taking screenshot: Boards list...');
    await page.screenshot({ path: 'screenshots/02-boards-list.png', fullPage: true });

    // 4. Board detail (Kanban view)
    console.log('Taking screenshot: Board detail...');
    await page.click('a[href*="/boards/"]');
    await page.waitForNavigation({ waitUntil: 'networkidle0' });
    await page.screenshot({ path: 'screenshots/03-board-detail.png', fullPage: false });

    // 5. Create new board page
    console.log('Taking screenshot: New board form...');
    await page.goto(`${baseUrl}/boards/new`, { waitUntil: 'networkidle0' });
    await page.screenshot({ path: 'screenshots/04-new-board.png', fullPage: false });

    // 6. Go to a board and view members
    console.log('Taking screenshot: Board members...');
    await page.goto(`${baseUrl}/boards`, { waitUntil: 'networkidle0' });
    // Find the Team Sprint board (has members)
    const teamBoardLink = await page.$('a[href*="/boards/2"]');
    if (teamBoardLink) {
      await teamBoardLink.click();
      await page.waitForNavigation({ waitUntil: 'networkidle0' });

      // Click members link
      const membersLink = await page.$('a[href*="/board_members"]');
      if (membersLink) {
        await membersLink.click();
        await page.waitForNavigation({ waitUntil: 'networkidle0' });
        await page.screenshot({ path: 'screenshots/05-board-members.png', fullPage: true });
      }
    }

    // 7. Edit board page
    console.log('Taking screenshot: Edit board...');
    await page.goto(`${baseUrl}/boards/1/edit`, { waitUntil: 'networkidle0' });
    await page.screenshot({ path: 'screenshots/06-edit-board.png', fullPage: true });

    console.log('All screenshots taken successfully!');
  } catch (error) {
    console.error('Error taking screenshots:', error);
  } finally {
    await browser.close();
  }
}

takeScreenshots();
