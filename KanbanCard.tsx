import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useDroppable } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { Calendar, User } from "lucide-react";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

interface CardProps {
  card: {
    id: number;
    title: string;
    description?: string | null;
    priority: string;
    dueDate?: Date | null;
    position: number;
    assignees?: Array<{ id: number; name: string | null; email: string | null }>;
  };
  onCardClick?: (cardId: number) => void;
}

export function Card({ card, onCardClick }: CardProps) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: card.id,
  });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...attributes}
      {...listeners}
      onClick={() => onCardClick?.(card.id)}
      className={`kanban-card priority-${card.priority} ${isDragging ? "dragging" : ""}`}
    >
      <div className="flex items-start justify-between mb-2">
        <h4 className="font-semibold text-sm">{card.title}</h4>
        <span
          className={`text-xs px-2 py-1 rounded flex-shrink-0 ml-2 ${
            card.priority === "urgent"
              ? "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300"
              : card.priority === "high"
              ? "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-300"
              : card.priority === "medium"
              ? "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-300"
              : "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"
          }`}
        >
          {card.priority}
        </span>
      </div>

      {card.description && (
        <p className="text-sm text-muted-foreground mb-3 line-clamp-2">{card.description}</p>
      )}

      <div className="flex items-center justify-between text-xs text-muted-foreground">
        <div className="flex items-center gap-2">
          {card.dueDate && (
            <div className="flex items-center gap-1">
              <Calendar className="w-3 h-3" />
              <span>{new Date(card.dueDate).toLocaleDateString()}</span>
            </div>
          )}
        </div>

        {card.assignees && card.assignees.length > 0 && (
          <div className="flex -space-x-2">
            {card.assignees.slice(0, 3).map((assignee) => (
              <Avatar key={assignee.id} className="w-6 h-6 border-2 border-background">
                <AvatarFallback className="text-xs">
                  {assignee.name?.charAt(0).toUpperCase() || assignee.email?.charAt(0).toUpperCase() || "?"}
                </AvatarFallback>
              </Avatar>
            ))}
            {card.assignees.length > 3 && (
              <Avatar className="w-6 h-6 border-2 border-background">
                <AvatarFallback className="text-xs">+{card.assignees.length - 3}</AvatarFallback>
              </Avatar>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

interface ColumnProps {
  column: {
    id: number;
    name: string;
  };
  cards: Array<{
    id: number;
    title: string;
    description?: string | null;
    priority: string;
    dueDate?: Date | null;
    position: number;
    assignees?: Array<{ id: number; name: string | null; email: string | null }>;
  }>;
  onCardClick?: (cardId: number) => void;
}

export function Column({ column, cards, onCardClick }: ColumnProps) {
  const { setNodeRef } = useDroppable({
    id: `column-${column.id}`,
  });

  const sortedCards = [...cards].sort((a, b) => a.position - b.position);

  return (
    <div className="kanban-column min-w-[300px] max-w-[300px]">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-semibold text-sm uppercase tracking-wide text-muted-foreground">
          {column.name}
        </h3>
        <span className="text-xs bg-muted px-2 py-1 rounded-full">{cards.length}</span>
      </div>

      <div ref={setNodeRef} className="flex-1 space-y-0">
        <SortableContext items={cards.map((c) => c.id)} strategy={verticalListSortingStrategy}>
          {sortedCards.map((card) => (
            <Card key={card.id} card={card} onCardClick={onCardClick} />
          ))}
        </SortableContext>

        {cards.length === 0 && (
          <div className="text-center py-8 text-sm text-muted-foreground">
            Drop cards here
          </div>
        )}
      </div>
    </div>
  );
}
