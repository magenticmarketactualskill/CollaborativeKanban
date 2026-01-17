import { useState, useEffect } from "react";
import { trpc } from "@/lib/trpc";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Calendar, Trash2, Save } from "lucide-react";
import { toast } from "sonner";
import { format } from "date-fns";

interface CardDetailSheetProps {
  cardId: number | null;
  boardId: number;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function CardDetailSheet({ cardId, boardId, open, onOpenChange }: CardDetailSheetProps) {
  const utils = trpc.useUtils();
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState<"low" | "medium" | "high" | "urgent">("medium");
  const [dueDate, setDueDate] = useState("");

  const { data: card } = trpc.cards.get.useQuery(
    { cardId: cardId! },
    { enabled: cardId !== null && open }
  );

  const updateCard = trpc.cards.update.useMutation({
    onSuccess: () => {
      utils.cards.list.invalidate({ boardId });
      toast.success("Card updated successfully");
      onOpenChange(false);
    },
    onError: () => {
      toast.error("Failed to update card");
    },
  });

  const deleteCard = trpc.cards.delete.useMutation({
    onSuccess: () => {
      utils.cards.list.invalidate({ boardId });
      toast.success("Card deleted successfully");
      onOpenChange(false);
    },
    onError: () => {
      toast.error("Failed to delete card");
    },
  });

  // Update form when card data loads
  useEffect(() => {
    if (card) {
      setTitle(card.title);
      setDescription(card.description || "");
      setPriority(card.priority as any);
      setDueDate(card.dueDate ? format(new Date(card.dueDate), "yyyy-MM-dd") : "");
    }
  }, [card]);

  const handleSave = () => {
    if (!cardId) return;

    updateCard.mutate({
      cardId,
      title,
      description: description || undefined,
      priority,
      dueDate: dueDate ? new Date(dueDate) : null,
    });
  };

  const handleDelete = () => {
    if (!cardId) return;
    if (!confirm("Are you sure you want to delete this card?")) return;

    deleteCard.mutate({ cardId });
  };

  if (!card) return null;

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-[500px] overflow-y-auto">
        <SheetHeader>
          <SheetTitle>Card Details</SheetTitle>
        </SheetHeader>

        <div className="mt-6 space-y-6">
          <div>
            <Label htmlFor="card-title">Title</Label>
            <Input
              id="card-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Card title"
            />
          </div>

          <div>
            <Label htmlFor="card-description">Description</Label>
            <Textarea
              id="card-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Add a description..."
              rows={5}
            />
          </div>

          <div>
            <Label htmlFor="card-priority">Priority</Label>
            <Select value={priority} onValueChange={(value: any) => setPriority(value)}>
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

          <div>
            <Label htmlFor="card-due-date">Due Date</Label>
            <div className="flex items-center gap-2">
              <Calendar className="w-4 h-4 text-muted-foreground" />
              <Input
                id="card-due-date"
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
              />
            </div>
          </div>

          {card.assignees && card.assignees.length > 0 && (
            <div>
              <Label>Assigned To</Label>
              <div className="mt-2 space-y-2">
                {card.assignees.map((assignee) => (
                  <div
                    key={assignee.id}
                    className="flex items-center gap-2 p-2 rounded-lg bg-muted"
                  >
                    <div className="w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm font-semibold">
                      {assignee.name?.charAt(0).toUpperCase() ||
                        assignee.email?.charAt(0).toUpperCase() ||
                        "?"}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate">
                        {assignee.name || "Unknown"}
                      </p>
                      <p className="text-xs text-muted-foreground truncate">
                        {assignee.email}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="flex gap-2 pt-4 border-t">
            <Button
              onClick={handleSave}
              disabled={updateCard.isPending}
              className="flex-1"
            >
              <Save className="w-4 h-4 mr-2" />
              {updateCard.isPending ? "Saving..." : "Save Changes"}
            </Button>
            <Button
              variant="destructive"
              onClick={handleDelete}
              disabled={deleteCard.isPending}
            >
              <Trash2 className="w-4 h-4" />
            </Button>
          </div>

          <div className="text-xs text-muted-foreground pt-4 border-t">
            <p>Created by {card.createdById}</p>
            <p>Created at {new Date(card.createdAt).toLocaleString()}</p>
            <p>Last updated {new Date(card.updatedAt).toLocaleString()}</p>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
