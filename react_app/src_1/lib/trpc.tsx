import { ReactNode } from "react";
import { QueryClient, QueryClientProvider, useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

// Mock data
const mockBoards = [
  { id: 1, name: "Product Roadmap", description: "Q1 2024 product features", level: "team" as const, ownerId: 1, createdAt: new Date(), updatedAt: new Date() },
  { id: 2, name: "Personal Tasks", description: "My daily tasks and goals", level: "personal" as const, ownerId: 1, createdAt: new Date(), updatedAt: new Date() },
  { id: 3, name: "Marketing Campaign", description: "Spring marketing initiatives", level: "group" as const, ownerId: 1, createdAt: new Date(), updatedAt: new Date() },
  { id: 4, name: "Company OKRs", description: "Organization-wide objectives", level: "enterprise" as const, ownerId: 1, createdAt: new Date(), updatedAt: new Date() },
];

const mockColumns = [
  { id: 1, boardId: 1, name: "Backlog", position: 0, createdAt: new Date(), updatedAt: new Date() },
  { id: 2, boardId: 1, name: "In Progress", position: 1, createdAt: new Date(), updatedAt: new Date() },
  { id: 3, boardId: 1, name: "Review", position: 2, createdAt: new Date(), updatedAt: new Date() },
  { id: 4, boardId: 1, name: "Done", position: 3, createdAt: new Date(), updatedAt: new Date() },
];

const mockCards = [
  { id: 1, boardId: 1, columnId: 1, title: "Design new landing page", description: "Create wireframes and mockups for the new landing page", priority: "high" as const, position: 0, dueDate: null, createdById: 1, createdAt: new Date(), updatedAt: new Date() },
  { id: 2, boardId: 1, columnId: 1, title: "Implement user authentication", description: "Set up OAuth2 with Google and GitHub", priority: "urgent" as const, position: 1, dueDate: null, createdById: 1, createdAt: new Date(), updatedAt: new Date() },
  { id: 3, boardId: 1, columnId: 2, title: "Build dashboard components", description: "Create reusable chart components", priority: "medium" as const, position: 0, dueDate: null, createdById: 1, createdAt: new Date(), updatedAt: new Date() },
  { id: 4, boardId: 1, columnId: 3, title: "API documentation", description: "Write OpenAPI specs for all endpoints", priority: "low" as const, position: 0, dueDate: null, createdById: 1, createdAt: new Date(), updatedAt: new Date() },
  { id: 5, boardId: 1, columnId: 4, title: "Set up CI/CD pipeline", description: "Configure GitHub Actions for automated testing", priority: "medium" as const, position: 0, dueDate: null, createdById: 1, createdAt: new Date(), updatedAt: new Date() },
];

// Store for mutations
let boards = [...mockBoards];
let columns = [...mockColumns];
let cards = [...mockCards];
let nextBoardId = 5;
let nextCardId = 6;

// Mock tRPC-like hooks
export const trpc = {
  useUtils: () => {
    const queryClient = useQueryClient();
    return {
      boards: {
        list: {
          invalidate: () => queryClient.invalidateQueries({ queryKey: ["boards"] }),
        },
      },
      columns: {
        list: {
          invalidate: (params: { boardId: number }) => queryClient.invalidateQueries({ queryKey: ["columns", params.boardId] }),
        },
      },
      cards: {
        list: {
          invalidate: (params: { boardId: number }) => queryClient.invalidateQueries({ queryKey: ["cards", params.boardId] }),
          cancel: async (params: { boardId: number }) => queryClient.cancelQueries({ queryKey: ["cards", params.boardId] }),
          getData: (params: { boardId: number }) => queryClient.getQueryData(["cards", params.boardId]) as typeof cards,
          setData: (params: { boardId: number }, updater: (old: typeof cards | undefined) => typeof cards | undefined) => {
            queryClient.setQueryData(["cards", params.boardId], updater);
          },
        },
        get: {
          invalidate: (params: { id: number }) => queryClient.invalidateQueries({ queryKey: ["card", params.id] }),
        },
      },
    };
  },

  boards: {
    list: {
      useQuery: () => useQuery({
        queryKey: ["boards"],
        queryFn: () => boards,
      }),
    },
    get: {
      useQuery: (params: { id: number }) => useQuery({
        queryKey: ["board", params.id],
        queryFn: () => boards.find(b => b.id === params.id),
      }),
    },
    create: {
      useMutation: (options?: { onSuccess?: () => void; onError?: () => void }) => {
        const queryClient = useQueryClient();
        return useMutation({
          mutationFn: async (data: { name: string; description?: string; level: string }) => {
            const newBoard = {
              id: nextBoardId++,
              name: data.name,
              description: data.description || null,
              level: data.level as any,
              ownerId: 1,
              createdAt: new Date(),
              updatedAt: new Date(),
            };
            boards.push(newBoard);
            return newBoard;
          },
          onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["boards"] });
            options?.onSuccess?.();
          },
          onError: options?.onError,
        });
      },
    },
  },

  columns: {
    list: {
      useQuery: (params: { boardId: number }) => useQuery({
        queryKey: ["columns", params.boardId],
        queryFn: () => columns.filter(c => c.boardId === params.boardId).sort((a, b) => a.position - b.position),
      }),
    },
  },

  cards: {
    list: {
      useQuery: (params: { boardId: number }) => useQuery({
        queryKey: ["cards", params.boardId],
        queryFn: () => cards.filter(c => c.boardId === params.boardId).sort((a, b) => a.position - b.position),
      }),
    },
    get: {
      useQuery: (params: { id: number }) => useQuery({
        queryKey: ["card", params.id],
        queryFn: () => cards.find(c => c.id === params.id),
      }),
    },
    create: {
      useMutation: (options?: { onSuccess?: () => void; onError?: () => void }) => {
        const queryClient = useQueryClient();
        return useMutation({
          mutationFn: async (data: { boardId: number; columnId: number; title: string; description?: string; priority: string; position: number }) => {
            const newCard = {
              id: nextCardId++,
              boardId: data.boardId,
              columnId: data.columnId,
              title: data.title,
              description: data.description || null,
              priority: data.priority as any,
              position: data.position,
              dueDate: null,
              createdById: 1,
              createdAt: new Date(),
              updatedAt: new Date(),
            };
            cards.push(newCard);
            return newCard;
          },
          onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["cards"] });
            options?.onSuccess?.();
          },
          onError: options?.onError,
        });
      },
    },
    move: {
      useMutation: (options?: { onMutate?: (variables: any) => any; onError?: (err: any, variables: any, context: any) => void; onSettled?: () => void }) => {
        return useMutation({
          mutationFn: async (data: { cardId: number; columnId: number; position: number }) => {
            const cardIndex = cards.findIndex(c => c.id === data.cardId);
            if (cardIndex !== -1) {
              cards[cardIndex] = { ...cards[cardIndex], columnId: data.columnId, position: data.position };
            }
            return cards[cardIndex];
          },
          onMutate: options?.onMutate,
          onError: options?.onError,
          onSettled: options?.onSettled,
        });
      },
    },
    update: {
      useMutation: (options?: { onSuccess?: () => void; onError?: () => void }) => {
        const queryClient = useQueryClient();
        return useMutation({
          mutationFn: async (data: { id: number; title?: string; description?: string; priority?: string }) => {
            const cardIndex = cards.findIndex(c => c.id === data.id);
            if (cardIndex !== -1) {
              cards[cardIndex] = { ...cards[cardIndex], ...data, updatedAt: new Date() };
            }
            return cards[cardIndex];
          },
          onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["cards"] });
            queryClient.invalidateQueries({ queryKey: ["card"] });
            options?.onSuccess?.();
          },
          onError: options?.onError,
        });
      },
    },
    delete: {
      useMutation: (options?: { onSuccess?: () => void; onError?: () => void }) => {
        const queryClient = useQueryClient();
        return useMutation({
          mutationFn: async (data: { id: number }) => {
            cards = cards.filter(c => c.id !== data.id);
            return { success: true };
          },
          onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["cards"] });
            options?.onSuccess?.();
          },
          onError: options?.onError,
        });
      },
    },
  },

  boardMembers: {
    list: {
      useQuery: (params: { boardId: number }) => useQuery({
        queryKey: ["boardMembers", params.boardId],
        queryFn: () => [
          { id: 1, boardId: params.boardId, userId: 1, role: "admin", user: { id: 1, name: "John Doe", email: "john@example.com" } },
          { id: 2, boardId: params.boardId, userId: 2, role: "editor", user: { id: 2, name: "Jane Smith", email: "jane@example.com" } },
        ],
      }),
    },
  },

  cardAssignments: {
    list: {
      useQuery: (params: { cardId: number }) => useQuery({
        queryKey: ["cardAssignments", params.cardId],
        queryFn: () => [],
      }),
    },
  },
};

// TRPCProvider component
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,
      refetchOnWindowFocus: false,
    },
  },
});

export function TRPCProvider({ children }: { children: ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
}
