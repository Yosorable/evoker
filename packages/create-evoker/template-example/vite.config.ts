import { defineConfig } from "vite"
import evoker from "@evoker/vite-plugin"
import { resolve } from "path"

// https://vitejs.dev/config/
export default defineConfig(() => {
  return {
    resolve: {
      alias: {
        "@": resolve(__dirname, "./src")
      }
    },
    plugins: [
      evoker({
        devtools: {
          host: true
        }
      })
    ]
  }
})
