import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// base: "./" so a built static bundle works when opened from any path (the "in the repo" floor).
export default defineConfig({
  base: "./",
  plugins: [react()],
  server: { port: 5273, open: true },
});
