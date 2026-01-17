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

describe("boards.create", () => {
  it("creates a board with default columns", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const result = await caller.boards.create({
      name: "Test Board",
      description: "A test board",
      level: "personal",
    });

    expect(result).toHaveProperty("boardId");
    expect(typeof result.boardId).toBe("number");
  });

  it("creates boards at different organizational levels", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const levels = ["personal", "team", "group", "enterprise"] as const;

    for (const level of levels) {
      const result = await caller.boards.create({
        name: `${level} Board`,
        level,
      });

      expect(result).toHaveProperty("boardId");
    }
  });
});

describe("boards.list", () => {
  it("returns boards owned by the user", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    // Create a board
    await caller.boards.create({
      name: "My Board",
      level: "personal",
    });

    const boards = await caller.boards.list();

    expect(Array.isArray(boards)).toBe(true);
    expect(boards.length).toBeGreaterThan(0);
    expect(boards[0]).toHaveProperty("name");
    expect(boards[0]).toHaveProperty("level");
  });
});

describe("boards.get", () => {
  it("returns a board by ID for the owner", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "team",
    });

    const board = await caller.boards.get({ boardId });

    expect(board).toBeDefined();
    expect(board.id).toBe(boardId);
    expect(board.name).toBe("Test Board");
    expect(board.level).toBe("team");
  });

  it("throws error for non-existent board", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    await expect(
      caller.boards.get({ boardId: 999999 })
    ).rejects.toThrow("Board not found");
  });
});

describe("boards.update", () => {
  it("updates board name and description", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Original Name",
      level: "personal",
    });

    await caller.boards.update({
      boardId,
      name: "Updated Name",
      description: "Updated description",
    });

    const board = await caller.boards.get({ boardId });

    expect(board.name).toBe("Updated Name");
    expect(board.description).toBe("Updated description");
  });
});

describe("boards.delete", () => {
  it("deletes a board owned by the user", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Board to Delete",
      level: "personal",
    });

    const result = await caller.boards.delete({ boardId });

    expect(result.success).toBe(true);

    // Verify board is deleted
    await expect(
      caller.boards.get({ boardId })
    ).rejects.toThrow("Board not found");
  });
});
