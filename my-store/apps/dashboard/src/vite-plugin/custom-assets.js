/**
 * Custom login sidebar artwork.
 *
 * `@spree/dashboard` ships its own `login_sidebar_background.png` /
 * `login_sidebar_background_dark.png` (imported by the shared AuthShell in
 * `src/components/spree/auth-shell.tsx`). This plugin rewrites those two
 * imports to the project-local copies in `src/assets/`, so the login screen
 * artwork is swapped without touching the framework package and survives
 * `pnpm install` / rebuilds — the override is a config-level resolve, not a
 * patched file in node_modules.
 *
 * Drop a new image at `src/assets/login_sidebar_background.png` (or
 * `..._dark.png`) and rebuild; no other change is needed.
 */

import path from 'node:path'
import { fileURLToPath } from 'node:url'

// Plugin lives in src/vite-plugin/, assets live one level up in src/assets/.
const HERE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'assets')

// Framework assets this overrides. Add an entry here to redirect any other
// framework asset to a project-local file.
const OVERRIDES = {
  'login_sidebar_background.png': path.join(HERE, 'login_sidebar_background.png'),
  'login_sidebar_background_dark.png': path.join(HERE, 'login_sidebar_background_dark.png'),
}

export function customAssetsPlugin() {
  return {
    name: 'spree-custom-login-assets',
    enforce: 'pre',
    resolveId(source) {
      // Match the bare asset name the framework imports (relative paths from
      // its own src resolve to the same basename); only redirect our two
      // files, leave everything else to the default resolver.
      for (const [name, local] of Object.entries(OVERRIDES)) {
        if (source === name || source.endsWith(`/${name}`) || source.endsWith(`\\${name}`)) {
          return local
        }
      }
      return null
    },
  }
}
