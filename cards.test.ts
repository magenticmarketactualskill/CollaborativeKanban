import { describe, expect, it } from "vitest";
import { appRouter } from "./routers";
import type { TrpcContext } from "./_core/context";

type AuthenticatedUser = NonNullable<TrpcContext["user"]>;

function createAuthContext(userId: number = 1, role: "user" | "admin" = "user"): TrpcContext {
  const user: AuthenticatedUser = {
    id: userId,
    openId: `test-user-${userId}`,
    email: `user${userId}@example.com`,
    name: `Test User ${userId}`,
    loginMethod: "manus",
    role,
    createdAt: new Date(),
    updatedAt: new Date(),
    lastSignedIn: new Date(),
  };

  return {
    user,
    req: {
      protocol: "https",
      headers: {},
    } as TrpcContext["req"],
    res: {} as TrpcContext["res"],
  };
}

describe("cards.create", () => {
  it("creates a card in a board", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    // Create a board first
    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "personal",
    });

    // Get columns
    const columns = await caller.columns.list({ boardId });
    const columnId = columns[0].id;

    // Create a card
    const result = await caller.cards.create({
      boardId,
      columnId,
      title: "Test Card",
      description: "Test description",
      priority: "high",
      position: 0,
    });

    expect(result).toHaveProperty("cardId");
    expect(typeof result.cardId).toBe("number");
  });

  it("creates cards with different priorities", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "personal",
    });

    const columns = await caller.columns.list({ boardId });
    const columnId = columns[0].id;

    const priorities = ["low", "medium", "high", "urgent"] as const;

    for (const priority of priorities) {
      const result = await caller.cards.create({
        boardId,
        columnId,
        title: `${priority} priority card`,
        priority,
        position: 0,
      });

      expect(result).toHaveProperty("cardId");
    }
  });
});

describe("cards.list", () => {
  it("returns all cards for a board", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "personal",
    });

    const columns = await caller.columns.list({ boardId });
    const columnId = columns[0].id;

    // Create multiple cards
    await caller.cards.create({
      boardId,
      columnId,
      title: "Card 1",
      position: 0,
    });

    await caller.cards.create({
      boardId,
      columnId,
      title: "Card 2",
      position: 1,
    });

    const cards = await caller.cards.list({ boardId });

    expect(Array.isArray(cards)).toBe(true);
    expect(cards.length).toBe(2);
    expect(cards[0]).toHaveProperty("title");
    expect(cards[0]).toHaveProperty("assignees");
  });
});

describe("cards.get", () => {
  it("returns a card by ID", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "personal",
    });

    const columns = await caller.columns.list({ boardId });
    const columnId = columns[0].id;

    const { cardId } = await caller.cards.create({
      boardId,
      columnId,
      title: "Test Card",
      description: "Test description",
      priority: "urgent",
      position: 0,
    });

    const card = await caller.cards.get({ cardId });

    expect(card).toBeDefined();
    expect(card.id).toBe(cardId);
    expect(card.title).toBe("Test Card");
    expect(card.description).toBe("Test description");
    expect(card.priority).toBe("urgent");
  });
});

describe("cards.update", () => {
  it("updates card properties", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "personal",
    });

    const columns = await caller.columns.list({ boardId });
    const columnId = columns[0].id;

    const { cardId } = await caller.cards.create({
      boardId,
      columnId,
      title: "Original Title",
      priority: "low",
      position: 0,
    });

    await caller.cards.update({
      cardId,
      title: "Updated Title",
      description: "New description",
      priority: "high",
    });

    const card = await caller.cards.get({ cardId });

    expect(card.title).toBe("Updated Title");
    expect(card.description).toBe("New description");
    expect(card.priority).toBe("high");
  });
});

describe("cards.move", () => {
  it("moves a card to a different column", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "personal",
    });

    const columns = await caller.columns.list({ boardId });
    const sourceColumnId = columns[0].id;
    const targetColumnId = columns[1].id;

    const { cardId } = await caller.cards.create({
      boardId,
      columnId: sourceColumnId,
      title: "Card to Move",
      position: 0,
    });

    await caller.cards.move({
      cardId,
      columnId: targetColumnId,
      position: 0,
    });

    const card = await caller.cards.get({ cardId });

    expect(card.columnId).toBe(targetColumnId);
    expect(card.position).toBe(0);
  });
});

describe("cards.delete", () => {
  it("deletes a card", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "personal",
    });

    const columns = await caller.columns.list({ boardId });
    const columnId = columns[0].id;

    const { cardId } = await caller.cards.create({
      boardId,
      columnId,
      title: "Card to Delete",
      position: 0,
    });

    const result = await caller.cards.delete({ cardId });

    expect(result.success).toBe(true);

    // Verify card is deleted
    await expect(
      caller.cards.get({ cardId })
    ).rejects.toThrow("Card not found");
  });
});

describe("cards.assign and unassign", () => {
  it("assigns and unassigns users to cards", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "personal",
    });

    const columns = await caller.columns.list({ boardId });
    const columnId = columns[0].id;

    const { cardId } = await caller.cards.create({
      boardId,
      columnId,
      title: "Test Card",
      position: 0,
    });

    // Assign user to card
    await caller.cards.assign({
      cardId,
      userId: ctx.user!.id,
    });

    let card = await caller.cards.get({ cardId });
    expect(card.assignees).toHaveLength(1);
    expect(card.assignees![0].id).toBe(ctx.user!.id);

    // Unassign user from card
    await caller.cards.unassign({
      cardId,
      userId: ctx.user!.id,
    });

    card = await caller.cards.get({ cardId });
    expect(card.assignees).toHaveLength(0);
  });
});
