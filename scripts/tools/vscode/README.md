# NovaScript for VS Code

VS Code extension for NovaScript — the scenario scripting language used by Uni-Story visual novel engine.

## Features

- **Syntax highlighting**: Distinct colors for code blocks, dialogue, speakers, comments, and strings
- **Snippets**: Quick insert code templates for common patterns (chapter, dialogue, branch, VFX, etc.)
- **Language configuration**: Comment toggling, bracket matching, and auto-closing pairs

## Installation

```bash
# Copy to VS Code extensions directory
cp -r scripts/tools/vscode ~/.vscode/extensions/nova-script

# Or symlink for development
ln -s $(pwd)/scripts/tools/vscode ~/.vscode/extensions/nova-script
```

Then restart VS Code. NovaScript `.txt` files in `resources/scenarios/` will automatically get syntax highlighting.

## Snippets

| Prefix | Description |
|--------|-------------|
| `chapter` | Start a new chapter |
| `say` | Dialogue line |
| `show` | Show character standing |
| `bgm` | Play background music |
| `branch` | Branching choice |
| `jump` | Jump to label |
| `end` | Mark an ending |
| `trans` | Fade transition |
| `vfx` | Visual effect |
| `vset` | Set game variable |
| `minigame` | Launch minigame |
| `av` | Auto voice setup |

## File Associations

By default, the extension associates `.txt` and `.nova` files with NovaScript. To restrict to scenarios only, modify `package.json` to remove the `.txt` association.

## Development

The grammar is defined in `syntaxes/nova-script.tmLanguage.json` using the TextMate grammar format. Snippets are in `snippets/nova-script.json`.
