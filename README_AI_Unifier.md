# AI Code Unifier

A powerful tool for merging suggestions and edits from multiple AI models without conflicts. This tool helps you unify code improvements from different AI assistants while maintaining code quality and resolving conflicts intelligently.

## Features

- **Conflict Detection**: Automatically detects overlapping edits, conflicting imports, and function definitions
- **Multiple Merge Strategies**: Conservative, Aggressive, Manual, and Smart merging approaches
- **Syntax Validation**: Ensures the unified code is syntactically correct
- **Flexible Input**: Accepts suggestions from multiple AI models in JSON format
- **Comprehensive Logging**: Detailed logging for debugging and monitoring

## Installation

The tool is a standalone Python script with no external dependencies beyond the standard library.

```bash
# Make the script executable
chmod +x ai_unifier.py

# Or run directly with Python
python3 ai_unifier.py --help
```

## Usage

### Basic Usage

```bash
python3 ai_unifier.py original_file.py suggestions1.json suggestions2.json suggestions3.json
```

### Advanced Usage

```bash
python3 ai_unifier.py \
    --strategy smart \
    --output unified_code.py \
    --verbose \
    hypervisor_manager/menu.py \
    example_suggestions_model1.json \
    example_suggestions_model2.json \
    example_suggestions_model3.json \
    example_suggestions_model4.json
```

### Command Line Options

- `original_file`: Path to the original file to be modified
- `suggestions_files`: One or more JSON files containing AI suggestions
- `--strategy`: Merge strategy (`conservative`, `aggressive`, `manual`, `smart`)
- `--output`: Output file path (default: `original_file.unified`)
- `--verbose`: Enable detailed logging
- `--help`: Show help message

## Merge Strategies

### 1. Conservative Strategy
- Only applies non-conflicting changes
- For conflicts, chooses the edit with highest confidence
- Safest approach, minimal risk

### 2. Aggressive Strategy
- Applies all changes, resolves conflicts automatically
- Merges overlapping edits and combines imports
- May result in more changes but higher risk

### 3. Manual Strategy
- Presents all conflicts for manual resolution
- Requires human intervention for conflict resolution
- Most control but requires manual work

### 4. Smart Strategy (Recommended)
- Uses heuristics to choose the best approach
- Considers confidence scores, edit quality, and context
- Balances automation with quality

## Suggestion File Format

The tool expects JSON files with the following structure:

```json
{
  "suggestions": [
    {
      "model": "GPT-4",
      "file_path": "path/to/file.py",
      "start_line": 10,
      "end_line": 15,
      "old_content": "original code here",
      "new_content": "new code here",
      "confidence": 0.9,
      "type": "function_enhancement",
      "description": "Description of the change"
    }
  ]
}
```

### Field Descriptions

- `model`: Name of the AI model that generated the suggestion
- `file_path`: Path to the file being modified
- `start_line`: Starting line number (1-indexed)
- `end_line`: Ending line number (1-indexed)
- `old_content`: Original code to be replaced
- `new_content`: New code to replace with
- `confidence`: Confidence score (0.0 to 1.0)
- `type`: Type of edit (import, function_enhancement, refactoring, etc.)
- `description`: Human-readable description of the change

## Example Workflow

1. **Generate suggestions from multiple AI models**:
   ```bash
   # Ask different AI models to improve your code
   # Save their suggestions as JSON files
   ```

2. **Run the unifier**:
   ```bash
   python3 ai_unifier.py \
       --strategy smart \
       --verbose \
       hypervisor_manager/menu.py \
       model1_suggestions.json \
       model2_suggestions.json \
       model3_suggestions.json
   ```

3. **Review the results**:
   ```bash
   # Check the unified output
   cat hypervisor_manager/menu.py.unified
   
   # Review conflicts and warnings
   # The tool will show a summary of applied changes
   ```

4. **Apply the unified code**:
   ```bash
   # If satisfied with the results
   cp hypervisor_manager/menu.py.unified hypervisor_manager/menu.py
   ```

## Conflict Resolution

The tool automatically detects and resolves several types of conflicts:

### 1. Overlapping Edits
When multiple models suggest changes to the same lines:
- **Conservative**: Choose the edit with highest confidence
- **Aggressive**: Merge the changes
- **Smart**: Use heuristics to choose the best approach

### 2. Conflicting Imports
When models suggest different import statements:
- Automatically merges unique imports
- Removes duplicates
- Maintains proper import order

### 3. Conflicting Functions
When models suggest different versions of the same function:
- Chooses based on confidence and quality metrics
- Can merge complementary improvements

## Best Practices

1. **Use Smart Strategy**: The smart strategy provides the best balance of automation and quality
2. **Review Conflicts**: Always review the conflict resolution summary
3. **Test Unified Code**: Run tests on the unified code before applying
4. **Incremental Approach**: Start with small changes and gradually increase scope
5. **Backup Original**: Always keep a backup of the original file

## Troubleshooting

### Common Issues

1. **Syntax Errors**: The tool validates syntax but may miss some edge cases
2. **Import Conflicts**: Check that all required imports are present
3. **Function Signature Changes**: Ensure function calls match new signatures
4. **Indentation Issues**: Python is sensitive to indentation

### Debug Mode

Use `--verbose` flag to see detailed information about:
- Which edits are being applied
- Conflict detection and resolution
- Warnings and errors

## Integration with AI Models

### GPT-4 Integration Example
```python
# Generate suggestions in the required format
suggestions = {
    "suggestions": [
        {
            "model": "GPT-4",
            "file_path": "your_file.py",
            "start_line": 10,
            "end_line": 15,
            "old_content": "original code",
            "new_content": "improved code",
            "confidence": 0.9,
            "type": "enhancement",
            "description": "Add error handling"
        }
    ]
}

# Save to file
import json
with open("gpt4_suggestions.json", "w") as f:
    json.dump(suggestions, f, indent=2)
```

### Claude Integration Example
```python
# Similar structure for Claude
suggestions = {
    "suggestions": [
        {
            "model": "Claude-3",
            "file_path": "your_file.py",
            "start_line": 20,
            "end_line": 25,
            "old_content": "old function",
            "new_content": "new function with type hints",
            "confidence": 0.85,
            "type": "refactoring",
            "description": "Add type hints and improve readability"
        }
    ]
}
```

## Advanced Features

### Custom Conflict Resolution
You can extend the tool to add custom conflict resolution logic:

```python
class CustomAICodeUnifier(AICodeUnifier):
    def _resolve_smart(self, conflict: Conflict) -> str:
        # Add your custom logic here
        if conflict.conflict_type == ConflictType.OVERLAPPING_EDITS:
            # Custom resolution logic
            pass
        return super()._resolve_smart(conflict)
```

### Batch Processing
Process multiple files at once:

```bash
#!/bin/bash
for file in *.py; do
    python3 ai_unifier.py --strategy smart "$file" suggestions_*.json
done
```

## Contributing

The tool is designed to be extensible. You can:
- Add new conflict detection methods
- Implement custom merge strategies
- Add support for other programming languages
- Improve the conflict resolution heuristics

## License

This tool is provided as-is for educational and development purposes.