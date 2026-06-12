# Development Guide

Junction supports an isolated **Preview Mode** so that developers can build, run, and test modifications locally without conflicting with their installed production copy of Junction.

## Isolated Preview Build

To build and run an isolated preview version of Junction:

1. Build and register the preview bundle folder and CLI:
   ```bash
   ./build-app.sh debug --preview --register
   ```

2. Run the preview app:
   ```bash
   open "build/Junction Preview.app"
   ```

## Key Segregations in Preview Mode

When built with the `--preview` flag, Junction dynamically uses the following separate paths:
- **App Name**: `Junction Preview`
- **Bundle Identifier**: `dev.gideonsarfo.JunctionPreview`
- **URL Scheme**: `junction-preview://`
- **Application Support Folder**: `Library/Application Support/JunctionPreview` (for settings, history, and sockets)
- **Config Folder**: `.config/junction-preview` (for rules)

## Testing Local File Routing

To test the routing of local HTML files (`file:///` URLs):
- Run via terminal:
  ```bash
  open -b dev.gideonsarfo.JunctionPreview /path/to/file.html
  ```
- Or right-click a `.html` file in Finder, select **Open With**, and select **Junction Preview**.
