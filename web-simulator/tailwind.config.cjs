/** @type {import('tailwindcss').Config} */
module.exports = {
  // Tailwind only emits the classes it can see here. Miss a path and the
  // components render with their class names intact and no styles at all.
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {},
  },
  plugins: [],
}
