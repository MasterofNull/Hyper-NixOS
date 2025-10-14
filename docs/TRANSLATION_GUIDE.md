# Translation Guide

This guide provides platform-agnostic language translation support for Hyper-NixOS documentation.

## Quick Translation Access

### Google Translate (No Account Required)
Translate any documentation page instantly:
```
https://translate.google.com/translate?sl=en&tl=[TARGET_LANG]&u=[DOC_URL]
```

**Supported Languages**: 100+ languages including:
- Spanish (es)
- French (fr) 
- German (de)
- Chinese Simplified (zh-CN)
- Japanese (ja)
- Korean (ko)
- Portuguese (pt)
- Russian (ru)
- Arabic (ar)
- Hindi (hi)

### Local Translation Tools

#### 1. Argos Translate (Open Source, Offline)
```bash
# Install on any Linux system
pip install argostranslate

# Download language packages
argospm install translate-en_es  # English to Spanish
argospm install translate-en_fr  # English to French
argospm install translate-en_de  # English to German

# Translate a file
argos-translate --from en --to es < README.md > README_es.md
```

#### 2. LibreTranslate (Self-Hosted)
```bash
# Run with Docker (any platform)
docker run -ti --rm -p 5000:5000 libretranslate/libretranslate

# Access at http://localhost:5000
# API available for automation
```

#### 3. DeepL CLI (High Quality)
```bash
# Install deepl-cli
pip install deepl-cli

# Set API key (free tier available)
export DEEPL_API_KEY="your-key-here"

# Translate
deepl translate -t ES README.md
```

## Browser-Based Translation

### For End Users
Add this notice to user-facing documents:

```markdown
## 🌐 Language Support

This documentation is written in English. For other languages:

**Browser Translation** (Recommended):
- **Chrome/Edge**: Right-click → "Translate to [Your Language]"
- **Firefox**: Install [Firefox Translations](https://addons.mozilla.org/firefox/addon/firefox-translations/)
- **Safari**: Develop menu → "Translate Page"

**Online Translation**:
- [Google Translate](https://translate.google.com)
- [DeepL Translator](https://www.deepl.com/translator)
- Copy and paste any section you need translated

**Offline Translation**:
See our [Translation Guide](docs/TRANSLATION_GUIDE.md) for offline tools.
```

## Adding Translation Support to Documents

### 1. HTML Meta Tags (for web-hosted docs)
```html
<meta name="google" content="notranslate" />
<meta http-equiv="Content-Language" content="en" />
<link rel="alternate" hreflang="es" href="/docs/es/" />
<link rel="alternate" hreflang="fr" href="/docs/fr/" />
```

### 2. Markdown Header (for all docs)
Add to the top of user-facing documents:
```markdown
<!-- Language: en -->
<!-- For translations, see: https://translate.google.com/translate?sl=en&tl=YOUR_LANG&u=URL -->
```

### 3. Translation-Friendly Writing

**DO**:
- Use simple, clear sentences
- Define technical terms
- Use consistent terminology
- Include examples

**AVOID**:
- Idioms and colloquialisms
- Complex nested sentences
- Ambiguous pronouns
- Culture-specific references

## Command Translation Helper

For non-English speakers using the system:

```bash
#!/bin/bash
# translate-help.sh - Add to Hyper-NixOS

show_translation_help() {
    echo "For help in your language:"
    echo "  Español: hv help --translate es"
    echo "  Français: hv help --translate fr"
    echo "  Deutsch: hv help --translate de"
    echo "  中文: hv help --translate zh"
    echo "  日本語: hv help --translate ja"
    echo ""
    echo "Or use: translate-doc <file> <language-code>"
}

translate_doc() {
    local file="$1"
    local lang="$2"
    
    if command -v argos-translate &> /dev/null; then
        argos-translate --from en --to "$lang" < "$file"
    else
        echo "Opening in Google Translate..."
        xdg-open "https://translate.google.com/translate?sl=en&tl=$lang&u=file://$file"
    fi
}
```

## Community Translations

### Contributing Translations

1. Fork the repository
2. Create a `docs/translations/[lang]` directory
3. Translate key documents:
   - README.md
   - QUICK_START.md
   - INSTALLATION_GUIDE.md
4. Submit a pull request

### Translation Standards

- Maintain original formatting
- Keep code blocks unchanged
- Translate comments in examples
- Preserve links and references
- Update language references

## Automated Translation CI/CD

```yaml
# .github/workflows/translate.yml
name: Auto-Translate Docs

on:
  push:
    paths:
      - 'docs/**.md'
      - 'README.md'

jobs:
  translate:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        lang: [es, fr, de, zh-CN, ja]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.x'
      
      - name: Install Argos Translate
        run: |
          pip install argostranslate
          argospm install translate-en_${{ matrix.lang }}
      
      - name: Translate Documents
        run: |
          mkdir -p docs/translations/${{ matrix.lang }}
          for file in README.md docs/QUICK_START.md; do
            argos-translate --from en --to ${{ matrix.lang }} \
              < $file > docs/translations/${{ matrix.lang }}/$(basename $file)
          done
      
      - name: Create PR
        uses: peter-evans/create-pull-request@v5
        with:
          title: "Auto-translate to ${{ matrix.lang }}"
          branch: translate-${{ matrix.lang }}
```

## Platform-Specific Translation

### NixOS Integration
```nix
# Add to configuration.nix for system-wide translation support
environment.systemPackages = with pkgs; [
  argos-translate
  translate-shell  # Command-line translator
  crow-translate   # GUI translator
];
```

### Quick Commands
```bash
# Translate any command output
hv status | trans -brief :es

# Translate error messages
hv vm create test 2>&1 | trans -brief :fr

# Interactive translation
trans -shell
```

---

**Note**: This guide ensures documentation is accessible to non-English speakers while maintaining a single source of truth in English.