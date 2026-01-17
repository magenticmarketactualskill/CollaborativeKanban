import { COOKIE_NAME } from "@shared/const";
import { getSessionCookieOptions } from "./_core/cookies";
import { systemRouter } from "./_core/systemRouter";
import { publicProcedure, protectedProcedure, router } from "./_core/trpc";
import { z } from "zod";
import * as db from "./db";
import { TRPCError } from "@trpc/server";

export const appRouter = router({
  system: systemRouter,
  auth: router({
    me: publicProcedure.query(opts => opts.ctx.user),
    logout: publicProcedure.mutation(({ ctx }) => {
      const cookieOptions = getSessionCookieOptions(ctx.req);
      ctx.res.clearCookie(COOKIE_NAME, { ...cookieOptions, maxAge: -1 });
      return {
        success: true,
      } as const;
    }),
  }),

  // ============================================================================
  // Board Management
  // ============================================================================
  boards: router({
    // Create a new board
    create: protectedProcedure
      .input(z.object({
        name: z.string().min(1).max(255),
        description: z.string().optional(),
        level: z.enum(["personal", "team", "group", "enterprise"]),
      }))
      .mutation(async ({ ctx, input }) => {
        const boardId = await db.createBoard({
          name: input.name,
          description: input.description,
          level: input.level,
          ownerId: ctx.user.id,
        });

        // Ensure boardId is a valid number
        if (!boardId || isNaN(boardId)) {
          throw new TRPCError({ code: "INTERNAL_SERVER_ERROR", message: "Failed to create board" });
        }

        // Create default columns
        await db.createColumn({ boardId, name: "To Do", position: 0 });
        await db.createColumn({ boardId, name: "In Progress", position: 1 });
        await db.createColumn({ boardId, name: "Done", position: 2 });

        return { boardId };
      }),

    // Get all boards for current user
    list: protectedProcedure.query(async ({ ctx }) => {
      const boards = await db.getBoardsByUserId(ctx.user.id);
      return boards;
    }),

    // Get a specific board by ID
    get: protectedProcedure
      .input(z.object({ boardId: z.number() }))
      .query(async ({ ctx, input }) => {
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        // Check if user has access (owner or member)
        const isOwner = board.ownerId === ctx.user.id;
        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        
        if (!isOwner && !member) {
          throw new TRPCError({ code: "FORBIDDEN", message: "Access denied" });
        }

        return board;
      }),

    // Update a board
    update: protectedProcedure
      .input(z.object({
        boardId: z.number(),
        name: z.string().min(1).max(255).optional(),
        description: z.string().optional(),
      }))
      .mutation(async ({ ctx, input }) => {
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        // Only owner or admin members can update
        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        if (board.ownerId !== ctx.user.id && member?.role !== "admin") {
          throw new TRPCError({ code: "FORBIDDEN", message: "Access denied" });
        }

        await db.updateBoard(input.boardId, {
          name: input.name,
          description: input.description,
        });

        return { success: true };
      }),

    // Delete a board
    delete: protectedProcedure
      .input(z.object({ boardId: z.number() }))
      .mutation(async ({ ctx, input }) => {
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        // Only owner can delete
        if (board.ownerId !== ctx.user.id) {
          throw new TRPCError({ code: "FORBIDDEN", message: "Only the owner can delete the board" });
        }

        await db.deleteBoard(input.boardId);
        return { success: true };
      }),
  }),

  // ============================================================================
  // Column Management
  // ============================================================================
  columns: router({
    // Get columns for a board
    list: protectedProcedure
      .input(z.object({ boardId: z.number() }))
      .query(async ({ ctx, input }) => {
        // Check access
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        const isOwner = board.ownerId === ctx.user.id;
        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        
        if (!isOwner && !member) {
          throw new TRPCError({ code: "FORBIDDEN", message: "Access denied" });
        }

        return db.getColumnsByBoardId(input.boardId);
      }),

    // Create a new column
    create: protectedProcedure
      .input(z.object({
        boardId: z.number(),
        name: z.string().min(1).max(255),
        position: z.number(),
      }))
      .mutation(async ({ ctx, input }) => {
        // Check access
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        if (board.ownerId !== ctx.user.id && member?.role === "viewer") {
          throw new TRPCError({ code: "FORBIDDEN", message: "Viewers cannot create columns" });
        }

        const columnId = await db.createColumn({
          boardId: input.boardId,
          name: input.name,
          position: input.position,
        });

        return { columnId };
      }),

    // Update a column
    update: protectedProcedure
      .input(z.object({
        columnId: z.number(),
        name: z.string().min(1).max(255).optional(),
        position: z.number().optional(),
      }))
      .mutation(async ({ input }) => {
        await db.updateColumn(input.columnId, {
          name: input.name,
          position: input.position,
        });

        return { success: true };
      }),

    // Delete a column
    delete: protectedProcedure
      .input(z.object({ columnId: z.number() }))
      .mutation(async ({ input }) => {
        await db.deleteColumn(input.columnId);
        return { success: true };
      }),
  }),

  // ============================================================================
  // Card Management
  // ============================================================================
  cards: router({
    // Get cards for a board
    list: protectedProcedure
      .input(z.object({ boardId: z.number() }))
      .query(async ({ ctx, input }) => {
        // Check access
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        const isOwner = board.ownerId === ctx.user.id;
        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        
        if (!isOwner && !member) {
          throw new TRPCError({ code: "FORBIDDEN", message: "Access denied" });
        }

        const cards = await db.getCardsByBoardId(input.boardId);
        
        // Get assignments for all cards
        const cardsWithAssignments = await Promise.all(
          cards.map(async (card) => {
            const assignments = await db.getCardAssignments(card.id);
            return {
              ...card,
              assignees: assignments.map(a => a.user),
            };
          })
        );

        return cardsWithAssignments;
      }),

    // Get a specific card
    get: protectedProcedure
      .input(z.object({ cardId: z.number() }))
      .query(async ({ input }) => {
        const card = await db.getCardById(input.cardId);
        if (!card) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Card not found" });
        }

        const assignments = await db.getCardAssignments(card.id);
        return {
          ...card,
          assignees: assignments.map(a => a.user),
        };
      }),

    // Create a new card
    create: protectedProcedure
      .input(z.object({
        boardId: z.number(),
        columnId: z.number(),
        title: z.string().min(1).max(255),
        description: z.string().optional(),
        priority: z.enum(["low", "medium", "high", "urgent"]).default("medium"),
        position: z.number(),
        dueDate: z.date().optional(),
      }))
      .mutation(async ({ ctx, input }) => {
        // Check access
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        if (board.ownerId !== ctx.user.id && member?.role === "viewer") {
          throw new TRPCError({ code: "FORBIDDEN", message: "Viewers cannot create cards" });
        }

        const cardId = await db.createCard({
          boardId: input.boardId,
          columnId: input.columnId,
          title: input.title,
          description: input.description,
          priority: input.priority,
          position: input.position,
          dueDate: input.dueDate,
          createdById: ctx.user.id,
        });

        return { cardId };
      }),

    // Update a card
    update: protectedProcedure
      .input(z.object({
        cardId: z.number(),
        title: z.string().min(1).max(255).optional(),
        description: z.string().optional(),
        priority: z.enum(["low", "medium", "high", "urgent"]).optional(),
        dueDate: z.date().optional().nullable(),
      }))
      .mutation(async ({ input }) => {
        await db.updateCard(input.cardId, {
          title: input.title,
          description: input.description,
          priority: input.priority,
          dueDate: input.dueDate === null ? undefined : input.dueDate,
        });

        return { success: true };
      }),

    // Move a card to a different column or position
    move: protectedProcedure
      .input(z.object({
        cardId: z.number(),
        columnId: z.number(),
        position: z.number(),
      }))
      .mutation(async ({ input }) => {
        await db.updateCard(input.cardId, {
          columnId: input.columnId,
          position: input.position,
        });

        return { success: true };
      }),

    // Delete a card
    delete: protectedProcedure
      .input(z.object({ cardId: z.number() }))
      .mutation(async ({ input }) => {
        await db.deleteCard(input.cardId);
        return { success: true };
      }),

    // Assign a user to a card
    assign: protectedProcedure
      .input(z.object({
        cardId: z.number(),
        userId: z.number(),
      }))
      .mutation(async ({ input }) => {
        await db.assignCardToUser({
          cardId: input.cardId,
          userId: input.userId,
        });

        return { success: true };
      }),

    // Unassign a user from a card
    unassign: protectedProcedure
      .input(z.object({
        cardId: z.number(),
        userId: z.number(),
      }))
      .mutation(async ({ input }) => {
        await db.unassignCardFromUser(input.cardId, input.userId);
        return { success: true };
      }),
  }),

  // ============================================================================
  // Board Member Management
  // ============================================================================
  members: router({
    // Get members of a board
    list: protectedProcedure
      .input(z.object({ boardId: z.number() }))
      .query(async ({ ctx, input }) => {
        // Check access
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        const isOwner = board.ownerId === ctx.user.id;
        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        
        if (!isOwner && !member) {
          throw new TRPCError({ code: "FORBIDDEN", message: "Access denied" });
        }

        const members = await db.getBoardMembers(input.boardId);
        
        // Get owner info
        const owner = await db.getUserById(board.ownerId);
        
        return {
          owner,
          members: members.map(m => ({
            ...m.user,
            role: m.member.role,
            joinedAt: m.member.createdAt,
          })),
        };
      }),

    // Add a member to a board
    add: protectedProcedure
      .input(z.object({
        boardId: z.number(),
        userId: z.number(),
        role: z.enum(["viewer", "editor", "admin"]).default("editor"),
      }))
      .mutation(async ({ ctx, input }) => {
        // Check access - only owner or admin can add members
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        if (board.ownerId !== ctx.user.id && member?.role !== "admin") {
          throw new TRPCError({ code: "FORBIDDEN", message: "Only owner or admin can add members" });
        }

        await db.addBoardMember({
          boardId: input.boardId,
          userId: input.userId,
          role: input.role,
        });

        return { success: true };
      }),

    // Update member role
    updateRole: protectedProcedure
      .input(z.object({
        boardId: z.number(),
        userId: z.number(),
        role: z.enum(["viewer", "editor", "admin"]),
      }))
      .mutation(async ({ ctx, input }) => {
        // Check access - only owner or admin can update roles
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        if (board.ownerId !== ctx.user.id && member?.role !== "admin") {
          throw new TRPCError({ code: "FORBIDDEN", message: "Only owner or admin can update roles" });
        }

        await db.updateBoardMember(input.boardId, input.userId, {
          role: input.role,
        });

        return { success: true };
      }),

    // Remove a member from a board
    remove: protectedProcedure
      .input(z.object({
        boardId: z.number(),
        userId: z.number(),
      }))
      .mutation(async ({ ctx, input }) => {
        // Check access - only owner or admin can remove members
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        if (board.ownerId !== ctx.user.id && member?.role !== "admin") {
          throw new TRPCError({ code: "FORBIDDEN", message: "Only owner or admin can remove members" });
        }

        await db.removeBoardMember(input.boardId, input.userId);
        return { success: true };
      }),
  }),

  // ============================================================================
  // Activity Tracking
  // ============================================================================
  activity: router({
    // Log user activity on a board
    log: protectedProcedure
      .input(z.object({
        boardId: z.number(),
        activityType: z.enum(["viewing", "editing_card", "moving_card"]),
        cardId: z.number().optional(),
      }))
      .mutation(async ({ ctx, input }) => {
        await db.logBoardActivity({
          boardId: input.boardId,
          userId: ctx.user.id,
          activityType: input.activityType,
          cardId: input.cardId,
        });

        return { success: true };
      }),

    // Get recent activity for a board
    get: protectedProcedure
      .input(z.object({ boardId: z.number() }))
      .query(async ({ ctx, input }) => {
        // Check access
        const board = await db.getBoardById(input.boardId);
        if (!board) {
          throw new TRPCError({ code: "NOT_FOUND", message: "Board not found" });
        }

        const isOwner = board.ownerId === ctx.user.id;
        const member = await db.getBoardMember(input.boardId, ctx.user.id);
        
        if (!isOwner && !member) {
          throw new TRPCError({ code: "FORBIDDEN", message: "Access denied" });
        }

        const activities = await db.getBoardActivity(input.boardId);
        return activities.map(a => ({
          user: a.user,
          activityType: a.activity.activityType,
          cardId: a.activity.cardId,
          lastActiveAt: a.activity.lastActiveAt,
        }));
      }),
  }),
});

export type AppRouter = typeof appRouter;
