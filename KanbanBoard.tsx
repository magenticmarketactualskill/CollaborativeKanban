import { useState } from "react";
import {
  DndContext,
  DragEndEvent,
  DragOverlay,
  DragStartEvent,
  PointerSensor,
  useSensor,
  useSensors,
  closestCorners,
} from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { trpc } from "@/lib/trpc";
import { Card, Column } from "./KanbanCard";
import { CardDetailSheet } from "./CardDetailSheet";
import { Button } from "@/components/ui/button";
import { Plus, Settings } from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";

interface KanbanBoardProps {
  boardId: number;
}

export function KanbanBoard({ boardId }: KanbanBoardProps) {
  const utils = trpc.useUtils();
  const [activeCard, setActiveCard] = useState<any>(null);
  const [isCreateCardOpen, setIsCreateCardOpen] = useState(false);
  const [selectedColumnId, setSelectedColumnId] = useState<number | null>(null);
  const [selectedCardId, setSelectedCardId] = useState<number | null>(null);
  const [isCardDetailOpen, setIsCardDetailOpen] = useState(false);

  // Queries
  const { data: columns = [] } = trpc.columns.list.useQuery({ boardId });
  const { data: cards = [] } = trpc.cards.list.useQuery({ boardId });

  // Mutations
  const moveCard = trpc.cards.move.useMutation({
    onMutate: async ({ cardId, columnId, position }) => {
      await utils.cards.list.cancel({ boardId });
      const previousCards = utils.cards.list.getData({ boardId });

      utils.cards.list.setData({ boardId }, (old) => {
        if (!old) return old;
        return old.map((card) =>
          card.id === cardId ? { ...card, columnId, position } : card
        );
      });

      return { previousCards };
    },
    onError: (err, variables, context) => {
      if (context?.previousCards) {
        utils.cards.list.setData({ boardId }, context.previousCards);
      }
      toast.error("Failed to move card");
    },
    onSettled: () => {
      utils.cards.list.invalidate({ boardId });
    },
  });

  const createCard = trpc.cards.create.useMutation({
    onSuccess: () => {
      utils.cards.list.invalidate({ boardId });
      setIsCreateCardOpen(false);
      toast.success("Card created successfully");
    },
    onError: () => {
      toast.error("Failed to create card");
    },
  });

  // Drag and drop sensors
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8,
      },
    })
  );

  const handleDragStart = (event: DragStartEvent) => {
    const { active } = event;
    const card = cards.find((c) => c.id === active.id);
    setActiveCard(card);
  };

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    setActiveCard(null);

    if (!over) return;

    const activeCard = cards.find((c) => c.id === active.id);
    if (!activeCard) return;

    // Determine the target column
    let targetColumnId: number;
    let targetPosition: number;

    if (over.id.toString().startsWith("column-")) {
      // Dropped on a column
      targetColumnId = parseInt(over.id.toString().replace("column-", ""));
      const cardsInColumn = cards.filter((c) => c.columnId === targetColumnId);
      targetPosition = cardsInColumn.length;
    } else {
      // Dropped on another card
      const overCard = cards.find((c) => c.id === over.id);
      if (!overCard) return;
      targetColumnId = overCard.columnId;
      targetPosition = overCard.position;
    }

    // Only move if position or column changed
    if (activeCard.columnId !== targetColumnId || activeCard.position !== targetPosition) {
      moveCard.mutate({
        cardId: activeCard.id,
        columnId: targetColumnId,
        position: targetPosition,
      });
    }
  };

  const handleCreateCard = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    
    if (!selectedColumnId) {
      toast.error("Please select a column");
      return;
    }

    const cardsInColumn = cards.filter((c) => c.columnId === selectedColumnId);
    
    createCard.mutate({
      boardId,
      columnId: selectedColumnId,
      title: formData.get("title") as string,
      description: formData.get("description") as string || undefined,
      priority: (formData.get("priority") as any) || "medium",
      position: cardsInColumn.length,
    });
  };

  const handleCardClick = (cardId: number) => {
    setSelectedCardId(cardId);
    setIsCardDetailOpen(true);
  };

  return (
    <div className="h-full flex flex-col">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-bold">Board</h2>
        <div className="flex gap-2">
          <Dialog open={isCreateCardOpen} onOpenChange={setIsCreateCardOpen}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="w-4 h-4 mr-2" />
                New Card
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create New Card</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleCreateCard} className="space-y-4">
                <div>
                  <Label htmlFor="title">Title</Label>
                  <Input id="title" name="title" required />
                </div>
                <div>
                  <Label htmlFor="description">Description</Label>
                  <Textarea id="description" name="description" rows={3} />
                </div>
                <div>
                  <Label htmlFor="column">Column</Label>
                  <Select
                    value={selectedColumnId?.toString()}
                    onValueChange={(value) => setSelectedColumnId(parseInt(value))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select a column" />
                    </SelectTrigger>
                    <SelectContent>
                      {columns.map((col) => (
                        <SelectItem key={col.id} value={col.id.toString()}>
                          {col.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="priority">Priority</Label>
                  <Select name="priority" defaultValue="medium">
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="low">Low</SelectItem>
                      <SelectItem value="medium">Medium</SelectItem>
                      <SelectItem value="high">High</SelectItem>
                      <SelectItem value="urgent">Urgent</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <Button type="submit" className="w-full">
                  Create Card
                </Button>
              </form>
            </DialogContent>
          </Dialog>
          <Button variant="outline">
            <Settings className="w-4 h-4 mr-2" />
            Settings
          </Button>
        </div>
      </div>

      <DndContext
        sensors={sensors}
        collisionDetection={closestCorners}
        onDragStart={handleDragStart}
        onDragEnd={handleDragEnd}
      >
        <div className="flex gap-4 overflow-x-auto pb-4">
          {columns.map((column) => (
            <Column
              key={column.id}
              column={column}
              cards={cards.filter((c) => c.columnId === column.id)}
              onCardClick={handleCardClick}
            />
          ))}
        </div>

        <DragOverlay>
          {activeCard ? (
            <div className="kanban-card opacity-100 rotate-3 shadow-xl">
              <div className="flex items-start justify-between mb-2">
                <h4 className="font-semibold">{activeCard.title}</h4>
                <span
                  className={`text-xs px-2 py-1 rounded ${
                    activeCard.priority === "urgent"
                      ? "bg-red-100 text-red-700"
                      : activeCard.priority === "high"
                      ? "bg-orange-100 text-orange-700"
                      : activeCard.priority === "medium"
                      ? "bg-yellow-100 text-yellow-700"
                      : "bg-blue-100 text-blue-700"
                  }`}
                >
                  {activeCard.priority}
                </span>
              </div>
              {activeCard.description && (
                <p className="text-sm text-muted-foreground line-clamp-2">
                  {activeCard.description}
                </p>
              )}
            </div>
          ) : null}
        </DragOverlay>
      </DndContext>

      <CardDetailSheet
        cardId={selectedCardId}
        boardId={boardId}
        open={isCardDetailOpen}
        onOpenChange={setIsCardDetailOpen}
      />
    </div>
  );
}
