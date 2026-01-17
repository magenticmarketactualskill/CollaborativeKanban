// Mock authentication hook
export function useAuth() {
  return {
    user: {
      id: 1,
      name: "John Doe",
      email: "john@example.com",
      role: "admin",
    },
    isLoading: false,
    isAuthenticated: true,
    login: async () => {},
    logout: async () => {},
  };
}
