import { int, mysqlEnum, mysqlTable, text, timestamp, varchar, boolean } from "drizzle-orm/mysql-core";

/**
 * Core user table backing auth flow.
 */
export const users = mysqlTable("users", {
  id: int("id").autoincrement().primaryKey(),
  openId: varchar("openId", { length: 64 }).notNull().unique(),
  name: text("name"),
  email: varchar("email", { length: 320 }),
  loginMethod: varchar("loginMethod", { length: 64 }),
  role: mysqlEnum("role", ["user", "admin"]).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  lastSignedIn: timestamp("lastSignedIn").defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

/**
 * Boards table - supports Personal, Team, Group, and Enterprise levels
 */
export const boards = mysqlTable("boards", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 255 }).notNull(),
  description: text("description"),
  level: mysqlEnum("level", ["personal", "team", "group", "enterprise"]).notNull(),
  ownerId: int("ownerId").notNull(), // User who created the board
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type Board = typeof boards.$inferSelect;
export type InsertBoard = typeof boards.$inferInsert;

/**
 * Columns table - customizable workflow stages for each board
 */
export const columns = mysqlTable("columns", {
  id: int("id").autoincrement().primaryKey(),
  boardId: int("boardId").notNull(),
  name: varchar("name", { length: 255 }).notNull(),
  position: int("position").notNull(), // Order of columns in the board
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type Column = typeof columns.$inferSelect;
export type InsertColumn = typeof columns.$inferInsert;

/**
 * Cards table - tasks/items in the KanBan board
 */
export const cards = mysqlTable("cards", {
  id: int("id").autoincrement().primaryKey(),
  boardId: int("boardId").notNull(),
  columnId: int("columnId").notNull(),
  title: varchar("title", { length: 255 }).notNull(),
  description: text("description"),
  priority: mysqlEnum("priority", ["low", "medium", "high", "urgent"]).default("medium").notNull(),
  position: int("position").notNull(), // Order within the column
  dueDate: timestamp("dueDate"),
  createdById: int("createdById").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type Card = typeof cards.$inferSelect;
export type InsertCard = typeof cards.$inferInsert;

/**
 * Board members table - tracks who has access to which boards and their roles
 */
export const boardMembers = mysqlTable("boardMembers", {
  id: int("id").autoincrement().primaryKey(),
  boardId: int("boardId").notNull(),
  userId: int("userId").notNull(),
  role: mysqlEnum("role", ["viewer", "editor", "admin"]).default("editor").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type BoardMember = typeof boardMembers.$inferSelect;
export type InsertBoardMember = typeof boardMembers.$inferInsert;

/**
 * Card assignments table - tracks who is assigned to which cards
 */
export const cardAssignments = mysqlTable("cardAssignments", {
  id: int("id").autoincrement().primaryKey(),
  cardId: int("cardId").notNull(),
  userId: int("userId").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export type CardAssignment = typeof cardAssignments.$inferSelect;
export type InsertCardAssignment = typeof cardAssignments.$inferInsert;

/**
 * Board activity table - tracks real-time presence and activity
 */
export const boardActivity = mysqlTable("boardActivity", {
  id: int("id").autoincrement().primaryKey(),
  boardId: int("boardId").notNull(),
  userId: int("userId").notNull(),
  activityType: mysqlEnum("activityType", ["viewing", "editing_card", "moving_card"]).notNull(),
  cardId: int("cardId"), // Optional - specific card being interacted with
  lastActiveAt: timestamp("lastActiveAt").defaultNow().notNull(),
});

export type BoardActivity = typeof boardActivity.$inferSelect;
export type InsertBoardActivity = typeof boardActivity.$inferInsert;
