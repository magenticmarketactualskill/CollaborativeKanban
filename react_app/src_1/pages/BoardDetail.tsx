import { useRoute, useLocation } from "wouter";
import { trpc } from "@/lib/trpc";
import { KanbanBoard } from "@/components/KanbanBoard";
import { Button } from "@/components/ui/button";
import { ArrowLeft, Users, Settings } from "lucide-react";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";

export default function BoardDetail() {
  const [, params] = useRoute("/board/:id");
  const [, setLocation] = useLocation();
  const boardId = params?.id ? parseInt(params.id) : 0;

  const { data: board, isLoading: boardLoading } = trpc.boards.get.useQuery(
    { id: boardId },
  );

  const { data: members = [] } = trpc.boardMembers.list.useQuery(
    { boardId },
  );

  if (boardLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading board...</p>
        </div>
      </div>
    );
  }

  if (!board) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-2xl font-bold mb-2">Board not found</h2>
          <p className="text-muted-foreground mb-4">
            The board you're looking for doesn't exist or you don't have access to it.
          </p>
          <Button onClick={() => setLocation("/")}>
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Boards
          </Button>
        </div>
      </div>
    );
  }

  const getLevelColor = (level: string) => {
    switch (level) {
      case "personal":
        return "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300";
      case "team":
        return "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300";
      case "group":
        return "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300";
      case "enterprise":
        return "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-300";
      default:
        return "bg-gray-100 text-gray-700";
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <div className="border-b bg-card">
        <div className="container py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <Button variant="ghost" size="icon" onClick={() => setLocation("/")}>
                <ArrowLeft className="w-5 h-5" />
              </Button>
              <div>
                <div className="flex items-center gap-2">
                  <h1 className="text-2xl font-bold">{board.name}</h1>
                  <Badge className={getLevelColor(board.level)}>{board.level}</Badge>
                </div>
                {board.description && (
                  <p className="text-sm text-muted-foreground mt-1">{board.description}</p>
                )}
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Sheet>
                <SheetTrigger asChild>
                  <Button variant="outline">
                    <Users className="w-4 h-4 mr-2" />
                    Members
                  </Button>
                </SheetTrigger>
                <SheetContent>
                  <SheetHeader>
                    <SheetTitle>Board Members</SheetTitle>
                  </SheetHeader>
                  <div className="mt-6 space-y-4">
                    {members.length > 0 ? (
                      <div className="space-y-2">
                        {members.map((member: any) => (
                          <div
                            key={member.id}
                            className="flex items-center gap-3 p-3 rounded-lg border"
                          >
                            <Avatar>
                              <AvatarFallback>
                                {member.user?.name?.charAt(0).toUpperCase() ||
                                  member.user?.email?.charAt(0).toUpperCase() ||
                                  "?"}
                              </AvatarFallback>
                            </Avatar>
                            <div className="flex-1 min-w-0">
                              <p className="font-medium truncate">{member.user?.name || "Unknown"}</p>
                              <p className="text-sm text-muted-foreground truncate">
                                {member.user?.email}
                              </p>
                            </div>
                            <Badge variant="secondary">{member.role}</Badge>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="text-center py-8 text-sm text-muted-foreground">
                        No members yet. Invite team members to collaborate!
                      </div>
                    )}
                  </div>
                </SheetContent>
              </Sheet>

              <Button variant="outline">
                <Settings className="w-4 h-4 mr-2" />
                Settings
              </Button>
            </div>
          </div>
        </div>
      </div>

      <div className="container py-6">
        <KanbanBoard boardId={boardId} />
      </div>
    </div>
  );
}
