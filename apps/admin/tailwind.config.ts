import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "#0D0E14",
        foreground: "#F9FAFB",
        card: "#16181F",
        surface: "#1E2028",
        accent: "#6366F1",
        positive: "#10B981",
        negative: "#EF4444",
        "text-primary": "#F9FAFB",
        "text-secondary": "#9CA3AF",
        divider: "#2D2F3A",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "-apple-system", "sans-serif"],
      },
      borderRadius: {
        card: "12px",
        btn: "8px",
      },
    },
  },
  plugins: [],
};
export default config;
