/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{html,ts}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Space Grotesk', 'Avenir Next', 'sans-serif'],
        mono: ['IBM Plex Mono', 'SF Mono', 'monospace']
      }
    }
  },
  plugins: [require('daisyui')],
  daisyui: {
    themes: ['dracula']
  }
};
