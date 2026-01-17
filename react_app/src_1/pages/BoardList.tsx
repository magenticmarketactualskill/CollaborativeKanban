import { useState } from "react";
import { useAuth } from "@/_core/hooks/useAuth";
import { trpc } from "@/lib/trpc";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Plus, Users, Building, Globe, User } from "lucide-react";
import { toast } from "sonner";
import { Link } from "wouter";

export default function BoardList() {
  const { user } = useAuth();
  const utils = trpc.useUtils();
  const [isCreateOpen, setIsCreateOpen] = useState(false);

  const { data: boards = [], isLoading } = trpc.boards.list.useQuery();

  const createBoard = trpc.boards.create.useMutation({
    onSuccess: () => {
      utils.boards.list.invalidate();
      setIsCreateOpen(false);
      toast.success("Board created successfully");
    },
    onError: () => {
      toast.error("Failed to create board");
    },
  });

  const handleCreateBoard = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);

    createBoard.mutate({
      name: formData.get("name") as string,
      description: formData.get("description") as string || undefined,
      level: formData.get("level") as any,
    });
  };

  const getLevelIcon = (level: string) => {
    switch (level) {
      case "personal":
        return <User className="w-5 h-5" />;
      case "team":
        return <Users className="w-5 h-5" />;
      case "group":
        return <Building className="w-5 h-5" />;
      case "enterprise":
        return <Globe className="w-5 h-5" />;
      default:
        return null;
    }
  };

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

  const groupedBoards = {
    personal: boards.filter((b) => b.level === "personal"),
    team: boards.filter((b) => b.level === "team"),
    group: boards.filter((b) => b.level === "group"),
    enterprise: boards.filter((b) => b.level === "enterprise"),
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading boards...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="container py-8">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold mb-2">MagenticFactory</h1>
            <p className="text-muted-foreground">
              Collaborative KanBan boards for every organizational level
            </p>
          </div>
          <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
            <DialogTrigger asChild>
              <Button size="lg">
                <Plus className="w-4 h-4 mr-2" />
                New Board
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create New Board</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleCreateBoard} className="space-y-4">
                <div>
                  <Label htmlFor="name">Board Name</Label>
                  <Input id="name" name="name" placeholder="My Awesome Board" required />
                </div>
                <div>
                  <Label htmlFor="description">Description</Label>
                  <Textarea
                    id="description"
                    name="description"
                    placeholder="What is this board for?"
                    rows={3}
                  />
                </div>
                <div>
                  <Label htmlFor="level">Board Level</Label>
                  <Select name="level" defaultValue="personal">
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="personal">Personal</SelectItem>
                      <SelectItem value="team">Team</SelectItem>
                      <SelectItem value="group">Group</SelectItem>
                      <SelectItem value="enterprise">Enterprise</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <Button type="submit" className="w-full" disabled={createBoard.isPending}>
                  {createBoard.isPending ? "Creating..." : "Create Board"}
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        {boards.length === 0 ? (
          <Card className="text-center py-12">
            <CardContent>
              <div className="max-w-md mx-auto">
                <div className="w-16 h-16 bg-muted rounded-full flex items-center justify-center mx-auto mb-4">
                  <Plus className="w-8 h-8 text-muted-foreground" />
                </div>
                <h3 className="text-xl font-semibold mb-2">No boards yet</h3>
                <p className="text-muted-foreground mb-4">
                  Create your first board to start organizing tasks and collaborating with your team.
                </p>
                <Button onClick={() => setIsCreateOpen(true)}>
                  <Plus className="w-4 h-4 mr-2" />
                  Create Your First Board
                </Button>
              </div>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-8">
            {Object.entries(groupedBoards).map(([level, levelBoards]) => {
              if (levelBoards.length === 0) return null;

              return (
                <div key={level}>
                  <div className="flex items-center gap-2 mb-4">
                    <div className={`p-2 rounded-lg ${getLevelColor(level)}`}>
                      {getLevelIcon(level)}
                    </div>
                    <h2 className="text-xl font-semibold capitalize">{level} Boards</h2>
                    <span className="text-sm text-muted-foreground">({levelBoards.length})</span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {levelBoards.map((board) => (
                      <Link key={board.id} href={`/board/${board.id}`}>
                        <Card className="hover:shadow-lg transition-shadow cursor-pointer h-full">
                          <CardHeader>
                            <div className="flex items-start justify-between">
                              <div className="flex-1">
                                <CardTitle className="mb-2">{board.name}</CardTitle>
                                <CardDescription className="line-clamp-2">
                                  {board.description || "No description"}
                                </CardDescription>
                              </div>
                              <div className={`p-2 rounded-lg ${getLevelColor(board.level)}`}>
                                {getLevelIcon(board.level)}
                              </div>
                            </div>
                          </CardHeader>
                          <CardContent>
                            <div className="text-xs text-muted-foreground">
                              Updated {new Date(board.updatedAt).toLocaleDateString()}
                            </div>
                          </CardContent>
                        </Card>
                      </Link>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
