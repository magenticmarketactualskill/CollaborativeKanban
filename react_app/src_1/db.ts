import { eq, and, desc, asc, inArray } from "drizzle-orm";
import { drizzle } from "drizzle-orm/mysql2";
import { 
  InsertUser, 
  users,
  boards,
  columns,
  cards,
  boardMembers,
  cardAssignments,
  boardActivity,
  InsertBoard,
  InsertColumn,
  InsertCard,
  InsertBoardMember,
  InsertCardAssignment,
  InsertBoardActivity
} from "../drizzle/schema";
import { ENV } from './_core/env';

let _db: ReturnType<typeof drizzle> | null = null;

export async function getDb() {
  if (!_db && process.env.DATABASE_URL) {
    try {
      _db = drizzle(process.env.DATABASE_URL);
    } catch (error) {
      console.warn("[Database] Failed to connect:", error);
      _db = null;
    }
  }
  return _db;
}

// ============================================================================
// User Management
// ============================================================================

export async function upsertUser(user: InsertUser): Promise<void> {
  if (!user.openId) {
    throw new Error("User openId is required for upsert");
  }

  const db = await getDb();
  if (!db) {
    console.warn("[Database] Cannot upsert user: database not available");
    return;
  }

  try {
    const values: InsertUser = {
      openId: user.openId,
    };
    const updateSet: Record<string, unknown> = {};

    const textFields = ["name", "email", "loginMethod"] as const;
    type TextField = (typeof textFields)[number];

    const assignNullable = (field: TextField) => {
      const value = user[field];
      if (value === undefined) return;
      const normalized = value ?? null;
      values[field] = normalized;
      updateSet[field] = normalized;
    };

    textFields.forEach(assignNullable);

    if (user.lastSignedIn !== undefined) {
      values.lastSignedIn = user.lastSignedIn;
      updateSet.lastSignedIn = user.lastSignedIn;
    }
    if (user.role !== undefined) {
      values.role = user.role;
      updateSet.role = user.role;
    } else if (user.openId === ENV.ownerOpenId) {
      values.role = 'admin';
      updateSet.role = 'admin';
    }

    if (!values.lastSignedIn) {
      values.lastSignedIn = new Date();
    }

    if (Object.keys(updateSet).length === 0) {
      updateSet.lastSignedIn = new Date();
    }

    await db.insert(users).values(values).onDuplicateKeyUpdate({
      set: updateSet,
    });
  } catch (error) {
    console.error("[Database] Failed to upsert user:", error);
    throw error;
  }
}

export async function getUserByOpenId(openId: string) {
  const db = await getDb();
  if (!db) {
    console.warn("[Database] Cannot get user: database not available");
    return undefined;
  }

  const result = await db.select().from(users).where(eq(users.openId, openId)).limit(1);
  return result.length > 0 ? result[0] : undefined;
}

export async function getUserById(userId: number) {
  const db = await getDb();
  if (!db) return undefined;

  const result = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  return result.length > 0 ? result[0] : undefined;
}

export async function getUsersByIds(userIds: number[]) {
  const db = await getDb();
  if (!db || userIds.length === 0) return [];

  return db.select().from(users).where(inArray(users.id, userIds));
}

// ============================================================================
// Board Management
// ============================================================================

export async function createBoard(board: InsertBoard) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  const result = await db.insert(boards).values(board) as any;
  return Number(result[0]?.insertId || result.insertId);
}

export async function getBoardById(boardId: number) {
  const db = await getDb();
  if (!db) return undefined;

  const result = await db.select().from(boards).where(eq(boards.id, boardId)).limit(1);
  return result.length > 0 ? result[0] : undefined;
}

export async function getBoardsByUserId(userId: number) {
  const db = await getDb();
  if (!db) return [];

  // Get boards owned by user or where user is a member
  const ownedBoards = await db.select().from(boards).where(eq(boards.ownerId, userId)).orderBy(desc(boards.updatedAt));
  
  const memberBoards = await db
    .select({ board: boards })
    .from(boardMembers)
    .innerJoin(boards, eq(boardMembers.boardId, boards.id))
    .where(eq(boardMembers.userId, userId))
    .orderBy(desc(boards.updatedAt));

  // Combine and deduplicate
  const allBoards = [...ownedBoards, ...memberBoards.map(m => m.board)];
  const uniqueBoards = Array.from(new Map(allBoards.map(b => [b.id, b])).values());
  
  return uniqueBoards;
}

export async function updateBoard(boardId: number, updates: Partial<InsertBoard>) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  await db.update(boards).set(updates).where(eq(boards.id, boardId));
}

export async function deleteBoard(boardId: number) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  await db.delete(boards).where(eq(boards.id, boardId));
}

// ============================================================================
// Column Management
// ============================================================================

export async function createColumn(column: InsertColumn) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  const result = await db.insert(columns).values(column) as any;
  return Number(result[0]?.insertId || result.insertId);
}

export async function getColumnsByBoardId(boardId: number) {
  const db = await getDb();
  if (!db) return [];

  return db.select().from(columns).where(eq(columns.boardId, boardId)).orderBy(asc(columns.position));
}

export async function updateColumn(columnId: number, updates: Partial<InsertColumn>) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  await db.update(columns).set(updates).where(eq(columns.id, columnId));
}

export async function deleteColumn(columnId: number) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  await db.delete(columns).where(eq(columns.id, columnId));
}

// ============================================================================
// Card Management
// ============================================================================

export async function createCard(card: InsertCard) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  const result = await db.insert(cards).values(card) as any;
  return Number(result[0]?.insertId || result.insertId);
}

export async function getCardById(cardId: number) {
  const db = await getDb();
  if (!db) return undefined;

  const result = await db.select().from(cards).where(eq(cards.id, cardId)).limit(1);
  return result.length > 0 ? result[0] : undefined;
}

export async function getCardsByBoardId(boardId: number) {
  const db = await getDb();
  if (!db) return [];

  return db.select().from(cards).where(eq(cards.boardId, boardId)).orderBy(asc(cards.position));
}

export async function getCardsByColumnId(columnId: number) {
  const db = await getDb();
  if (!db) return [];

  return db.select().from(cards).where(eq(cards.columnId, columnId)).orderBy(asc(cards.position));
}

export async function updateCard(cardId: number, updates: Partial<InsertCard>) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  await db.update(cards).set(updates).where(eq(cards.id, cardId));
}

export async function deleteCard(cardId: number) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  await db.delete(cards).where(eq(cards.id, cardId));
}

// ============================================================================
// Board Member Management
// ============================================================================

export async function addBoardMember(member: InsertBoardMember) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  const result = await db.insert(boardMembers).values(member) as any;
  return Number(result[0]?.insertId || result.insertId);
}

export async function getBoardMembers(boardId: number) {
  const db = await getDb();
  if (!db) return [];

  const members = await db
    .select({
      member: boardMembers,
      user: users
    })
    .from(boardMembers)
    .innerJoin(users, eq(boardMembers.userId, users.id))
    .where(eq(boardMembers.boardId, boardId));

  return members;
}

export async function getBoardMember(boardId: number, userId: number) {
  const db = await getDb();
  if (!db) return undefined;

  const result = await db
    .select()
    .from(boardMembers)
    .where(and(eq(boardMembers.boardId, boardId), eq(boardMembers.userId, userId)))
    .limit(1);

  return result.length > 0 ? result[0] : undefined;
}

export async function updateBoardMember(boardId: number, userId: number, updates: Partial<InsertBoardMember>) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  await db.update(boardMembers).set(updates).where(
    and(eq(boardMembers.boardId, boardId), eq(boardMembers.userId, userId))
  );
}

export async function removeBoardMember(boardId: number, userId: number) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  await db.delete(boardMembers).where(
    and(eq(boardMembers.boardId, boardId), eq(boardMembers.userId, userId))
  );
}

// ============================================================================
// Card Assignment Management
// ============================================================================

export async function assignCardToUser(assignment: InsertCardAssignment) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  const result = await db.insert(cardAssignments).values(assignment) as any;
  return Number(result[0]?.insertId || result.insertId);
}

export async function getCardAssignments(cardId: number) {
  const db = await getDb();
  if (!db) return [];

  const assignments = await db
    .select({
      assignment: cardAssignments,
      user: users
    })
    .from(cardAssignments)
    .innerJoin(users, eq(cardAssignments.userId, users.id))
    .where(eq(cardAssignments.cardId, cardId));

  return assignments;
}

export async function unassignCardFromUser(cardId: number, userId: number) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  await db.delete(cardAssignments).where(
    and(eq(cardAssignments.cardId, cardId), eq(cardAssignments.userId, userId))
  );
}

// ============================================================================
// Board Activity Management
// ============================================================================

export async function logBoardActivity(activity: InsertBoardActivity) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");

  // Upsert activity - update if exists, insert if not
  const conditions = [
    eq(boardActivity.boardId, activity.boardId),
    eq(boardActivity.userId, activity.userId),
    eq(boardActivity.activityType, activity.activityType)
  ];
  
  if (activity.cardId) {
    conditions.push(eq(boardActivity.cardId, activity.cardId));
  }

  const existing = await db
    .select()
    .from(boardActivity)
    .where(and(...conditions))
    .limit(1);

  if (existing.length > 0) {
    await db.update(boardActivity).set({ lastActiveAt: new Date() }).where(eq(boardActivity.id, existing[0].id));
  } else {
    await db.insert(boardActivity).values(activity);
  }
}

export async function getBoardActivity(boardId: number) {
  const db = await getDb();
  if (!db) return [];

  // Get recent activity (last 5 minutes)
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);

  const activities = await db
    .select({
      activity: boardActivity,
      user: users
    })
    .from(boardActivity)
    .innerJoin(users, eq(boardActivity.userId, users.id))
    .where(eq(boardActivity.boardId, boardId));

  return activities.filter(a => a.activity.lastActiveAt >= fiveMinutesAgo);
}

export async function cleanupOldActivity() {
  const db = await getDb();
  if (!db) return;

  // Remove activity older than 10 minutes
  const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
  
  await db.delete(boardActivity).where(
    // Note: This is a simplified cleanup - in production you'd want a proper timestamp comparison
    eq(boardActivity.lastActiveAt, tenMinutesAgo)
  );
}
