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

describe("members.list", () => {
  it("returns board owner and members", async () => {
    const ctx = createAuthContext();
    const caller = appRouter.createCaller(ctx);

    const { boardId } = await caller.boards.create({
      name: "Test Board",
      level: "team",
    });

    const membersData = await caller.members.list({ boardId });

    expect(membersData).toHaveProperty("owner");
    expect(membersData).toHaveProperty("members");
    expect(membersData.owner).toBeDefined();
    expect(membersData.owner!.id).toBe(ctx.user!.id);
    expect(Array.isArray(membersData.members)).toBe(true);
  });
});

describe("members.add", () => {
  it("adds a member to a board", async () => {
    const ownerCtx = createAuthContext(1);
    const ownerCaller = appRouter.createCaller(ownerCtx);

    const { boardId } = await ownerCaller.boards.create({
      name: "Test Board",
      level: "team",
    });

    // Add a member (user ID 2)
    await ownerCaller.members.add({
      boardId,
      userId: 2,
      role: "editor",
    });

    const membersData = await ownerCaller.members.list({ boardId });

    expect(membersData.members).toHaveLength(1);
    expect(membersData.members[0].id).toBe(2);
    expect(membersData.members[0].role).toBe("editor");
  });

  it("adds members with different roles", async () => {
    const ownerCtx = createAuthContext(1);
    const ownerCaller = appRouter.createCaller(ownerCtx);

    const { boardId } = await ownerCaller.boards.create({
      name: "Test Board",
      level: "team",
    });

    const roles = ["viewer", "editor", "admin"] as const;

    for (let i = 0; i < roles.length; i++) {
      await ownerCaller.members.add({
        boardId,
        userId: i + 2,
        role: roles[i],
      });
    }

    const membersData = await ownerCaller.members.list({ boardId });

    expect(membersData.members).toHaveLength(3);
    expect(membersData.members.map(m => m.role)).toEqual(["viewer", "editor", "admin"]);
  });
});

describe("members.updateRole", () => {
  it("updates a member's role", async () => {
    const ownerCtx = createAuthContext(1);
    const ownerCaller = appRouter.createCaller(ownerCtx);

    const { boardId } = await ownerCaller.boards.create({
      name: "Test Board",
      level: "team",
    });

    // Add a member
    await ownerCaller.members.add({
      boardId,
      userId: 2,
      role: "viewer",
    });

    // Update role
    await ownerCaller.members.updateRole({
      boardId,
      userId: 2,
      role: "admin",
    });

    const membersData = await ownerCaller.members.list({ boardId });

    expect(membersData.members[0].role).toBe("admin");
  });
});

describe("members.remove", () => {
  it("removes a member from a board", async () => {
    const ownerCtx = createAuthContext(1);
    const ownerCaller = appRouter.createCaller(ownerCtx);

    const { boardId } = await ownerCaller.boards.create({
      name: "Test Board",
      level: "team",
    });

    // Add a member
    await ownerCaller.members.add({
      boardId,
      userId: 2,
      role: "editor",
    });

    let membersData = await ownerCaller.members.list({ boardId });
    expect(membersData.members).toHaveLength(1);

    // Remove the member
    await ownerCaller.members.remove({
      boardId,
      userId: 2,
    });

    membersData = await ownerCaller.members.list({ boardId });
    expect(membersData.members).toHaveLength(0);
  });
});
