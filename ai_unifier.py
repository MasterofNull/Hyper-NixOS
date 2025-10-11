#!/usr/bin/env python3
"""
AI Code Unifier - Tool for merging multiple AI model suggestions and edits

This tool helps unify suggestions and edits from multiple AI models without
overwriting each other. It provides conflict detection, resolution strategies,
and validation capabilities.
"""

import ast
import difflib
import json
import logging
import re
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple, Union
import argparse
import sys


class MergeStrategy(Enum):
    """Different strategies for merging AI suggestions"""
    CONSERVATIVE = "conservative"  # Only apply non-conflicting changes
    AGGRESSIVE = "aggressive"     # Apply all changes, resolve conflicts automatically
    MANUAL = "manual"            # Present conflicts for manual resolution
    SMART = "smart"              # Use heuristics to choose best changes


class ConflictType(Enum):
    """Types of conflicts that can occur"""
    OVERLAPPING_EDITS = "overlapping_edits"
    CONFLICTING_IMPORTS = "conflicting_imports"
    CONFLICTING_FUNCTIONS = "conflicting_functions"
    CONFLICTING_VARIABLES = "conflicting_variables"
    SYNTAX_ERROR = "syntax_error"


@dataclass
class CodeEdit:
    """Represents a single code edit from an AI model"""
    model_name: str
    file_path: str
    start_line: int
    end_line: int
    old_content: str
    new_content: str
    confidence: float = 1.0
    edit_type: str = "unknown"
    description: str = ""


@dataclass
class Conflict:
    """Represents a conflict between multiple edits"""
    conflict_type: ConflictType
    edits: List[CodeEdit]
    file_path: str
    description: str
    resolution: Optional[str] = None


@dataclass
class UnificationResult:
    """Result of unifying AI suggestions"""
    unified_code: str
    applied_edits: List[CodeEdit]
    conflicts: List[Conflict]
    warnings: List[str] = field(default_factory=list)
    success: bool = True


class AICodeUnifier:
    """Main class for unifying AI code suggestions and edits"""
    
    def __init__(self, strategy: MergeStrategy = MergeStrategy.SMART):
        self.strategy = strategy
        self.logger = self._setup_logging()
        
    def _setup_logging(self) -> logging.Logger:
        """Setup logging configuration"""
        logger = logging.getLogger("ai_unifier")
        logger.setLevel(logging.INFO)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            
        return logger
    
    def parse_ai_suggestions(self, suggestions_file: str) -> List[CodeEdit]:
        """Parse AI suggestions from a JSON file"""
        try:
            with open(suggestions_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            edits = []
            for suggestion in data.get('suggestions', []):
                edit = CodeEdit(
                    model_name=suggestion.get('model', 'unknown'),
                    file_path=suggestion.get('file_path', ''),
                    start_line=suggestion.get('start_line', 0),
                    end_line=suggestion.get('end_line', 0),
                    old_content=suggestion.get('old_content', ''),
                    new_content=suggestion.get('new_content', ''),
                    confidence=suggestion.get('confidence', 1.0),
                    edit_type=suggestion.get('type', 'unknown'),
                    description=suggestion.get('description', '')
                )
                edits.append(edit)
            
            return edits
        except Exception as e:
            self.logger.error(f"Failed to parse suggestions file {suggestions_file}: {e}")
            return []
    
    def detect_conflicts(self, edits: List[CodeEdit]) -> List[Conflict]:
        """Detect conflicts between multiple edits"""
        conflicts = []
        
        # Group edits by file
        file_edits = {}
        for edit in edits:
            if edit.file_path not in file_edits:
                file_edits[edit.file_path] = []
            file_edits[edit.file_path].append(edit)
        
        for file_path, file_edit_list in file_edits.items():
            # Check for overlapping line ranges
            conflicts.extend(self._detect_overlapping_edits(file_path, file_edit_list))
            
            # Check for conflicting imports
            conflicts.extend(self._detect_import_conflicts(file_path, file_edit_list))
            
            # Check for conflicting function definitions
            conflicts.extend(self._detect_function_conflicts(file_path, file_edit_list))
        
        return conflicts
    
    def _detect_overlapping_edits(self, file_path: str, edits: List[CodeEdit]) -> List[Conflict]:
        """Detect edits that overlap in line ranges"""
        conflicts = []
        
        for i, edit1 in enumerate(edits):
            for j, edit2 in enumerate(edits[i+1:], i+1):
                # Check if line ranges overlap
                if (edit1.start_line <= edit2.end_line and edit2.start_line <= edit1.end_line):
                    conflict = Conflict(
                        conflict_type=ConflictType.OVERLAPPING_EDITS,
                        edits=[edit1, edit2],
                        file_path=file_path,
                        description=f"Overlapping edits from {edit1.model_name} and {edit2.model_name}"
                    )
                    conflicts.append(conflict)
        
        return conflicts
    
    def _detect_import_conflicts(self, file_path: str, edits: List[CodeEdit]) -> List[Conflict]:
        """Detect conflicting import statements"""
        conflicts = []
        import_edits = [e for e in edits if 'import' in e.new_content.lower()]
        
        for i, edit1 in enumerate(import_edits):
            for j, edit2 in enumerate(import_edits[i+1:], i+1):
                if self._imports_conflict(edit1.new_content, edit2.new_content):
                    conflict = Conflict(
                        conflict_type=ConflictType.CONFLICTING_IMPORTS,
                        edits=[edit1, edit2],
                        file_path=file_path,
                        description=f"Conflicting imports from {edit1.model_name} and {edit2.model_name}"
                    )
                    conflicts.append(conflict)
        
        return conflicts
    
    def _detect_function_conflicts(self, file_path: str, edits: List[CodeEdit]) -> List[Conflict]:
        """Detect conflicting function definitions"""
        conflicts = []
        function_edits = [e for e in edits if 'def ' in e.new_content]
        
        for i, edit1 in enumerate(function_edits):
            for j, edit2 in enumerate(function_edits[i+1:], i+1):
                if self._functions_conflict(edit1.new_content, edit2.new_content):
                    conflict = Conflict(
                        conflict_type=ConflictType.CONFLICTING_FUNCTIONS,
                        edits=[edit1, edit2],
                        file_path=file_path,
                        description=f"Conflicting function definitions from {edit1.model_name} and {edit2.model_name}"
                    )
                    conflicts.append(conflict)
        
        return conflicts
    
    def _imports_conflict(self, content1: str, content2: str) -> bool:
        """Check if two import statements conflict"""
        # Simple heuristic: check for same module with different imports
        lines1 = [line.strip() for line in content1.split('\n') if 'import' in line]
        lines2 = [line.strip() for line in content2.split('\n') if 'import' in line]
        
        for line1 in lines1:
            for line2 in lines2:
                if self._extract_module_name(line1) == self._extract_module_name(line2):
                    return True
        return False
    
    def _functions_conflict(self, content1: str, content2: str) -> bool:
        """Check if two function definitions conflict"""
        func1 = self._extract_function_name(content1)
        func2 = self._extract_function_name(content2)
        return func1 and func2 and func1 == func2
    
    def _extract_module_name(self, import_line: str) -> str:
        """Extract module name from import statement"""
        match = re.match(r'from\s+(\w+)\s+import|import\s+(\w+)', import_line)
        return match.group(1) or match.group(2) if match else ""
    
    def _extract_function_name(self, content: str) -> Optional[str]:
        """Extract function name from function definition"""
        match = re.search(r'def\s+(\w+)', content)
        return match.group(1) if match else None
    
    def resolve_conflicts(self, conflicts: List[Conflict]) -> List[Conflict]:
        """Resolve conflicts based on the selected strategy"""
        resolved_conflicts = []
        
        for conflict in conflicts:
            if self.strategy == MergeStrategy.CONSERVATIVE:
                resolution = self._resolve_conservative(conflict)
            elif self.strategy == MergeStrategy.AGGRESSIVE:
                resolution = self._resolve_aggressive(conflict)
            elif self.strategy == MergeStrategy.SMART:
                resolution = self._resolve_smart(conflict)
            else:  # MANUAL
                resolution = None  # Leave for manual resolution
            
            conflict.resolution = resolution
            resolved_conflicts.append(conflict)
        
        return resolved_conflicts
    
    def _resolve_conservative(self, conflict: Conflict) -> str:
        """Conservative resolution: choose the edit with highest confidence"""
        best_edit = max(conflict.edits, key=lambda e: e.confidence)
        return f"Using edit from {best_edit.model_name} (confidence: {best_edit.confidence})"
    
    def _resolve_aggressive(self, conflict: Conflict) -> str:
        """Aggressive resolution: merge all edits"""
        if conflict.conflict_type == ConflictType.OVERLAPPING_EDITS:
            return "Merging overlapping edits"
        elif conflict.conflict_type == ConflictType.CONFLICTING_IMPORTS:
            return "Combining all imports"
        else:
            return "Applying all changes"
    
    def _resolve_smart(self, conflict: Conflict) -> str:
        """Smart resolution: use heuristics to choose best approach"""
        if conflict.conflict_type == ConflictType.OVERLAPPING_EDITS:
            # For overlapping edits, choose the one with better quality
            edit1, edit2 = conflict.edits[0], conflict.edits[1]
            if edit1.confidence > edit2.confidence:
                return f"Using {edit1.model_name} edit (higher confidence)"
            elif len(edit1.new_content) > len(edit2.new_content):
                return f"Using {edit1.model_name} edit (more comprehensive)"
            else:
                return f"Using {edit2.model_name} edit"
        else:
            return self._resolve_conservative(conflict)
    
    def apply_edits(self, original_code: str, edits: List[CodeEdit], 
                   conflicts: List[Conflict]) -> UnificationResult:
        """Apply edits to original code and return unified result"""
        try:
            lines = original_code.split('\n')
            applied_edits = []
            warnings = []
            
            # Sort edits by line number (descending) to avoid line number shifts
            sorted_edits = sorted(edits, key=lambda e: e.start_line, reverse=True)
            
            for edit in sorted_edits:
                # Check if this edit conflicts with resolved conflicts
                conflicting = any(
                    edit in conflict.edits and conflict.resolution and 
                    "Using" in conflict.resolution and edit.model_name not in conflict.resolution
                    for conflict in conflicts
                )
                
                if not conflicting:
                    try:
                        # Apply the edit
                        new_lines = edit.new_content.split('\n')
                        lines[edit.start_line-1:edit.end_line] = new_lines
                        applied_edits.append(edit)
                    except Exception as e:
                        warnings.append(f"Failed to apply edit from {edit.model_name}: {e}")
            
            # Handle import conflicts by merging imports
            import_conflicts = [c for c in conflicts if c.conflict_type == ConflictType.CONFLICTING_IMPORTS]
            if import_conflicts:
                lines = self._merge_imports(lines, import_conflicts)
            
            unified_code = '\n'.join(lines)
            
            # Validate syntax
            if not self._validate_syntax(unified_code):
                warnings.append("Unified code has syntax errors")
            
            return UnificationResult(
                unified_code=unified_code,
                applied_edits=applied_edits,
                conflicts=conflicts,
                warnings=warnings,
                success=len(warnings) == 0
            )
            
        except Exception as e:
            self.logger.error(f"Failed to apply edits: {e}")
            return UnificationResult(
                unified_code=original_code,
                applied_edits=[],
                conflicts=conflicts,
                warnings=[f"Failed to unify code: {e}"],
                success=False
            )
    
    def _merge_imports(self, lines: List[str], import_conflicts: List[Conflict]) -> List[str]:
        """Merge conflicting import statements"""
        # Simple implementation: collect all unique imports
        all_imports = set()
        
        for conflict in import_conflicts:
            for edit in conflict.edits:
                import_lines = [line.strip() for line in edit.new_content.split('\n') 
                              if line.strip() and 'import' in line]
                all_imports.update(import_lines)
        
        # Find the first import line and replace with merged imports
        import_start = -1
        for i, line in enumerate(lines):
            if line.strip() and 'import' in line:
                import_start = i
                break
        
        if import_start >= 0:
            # Remove existing imports and add merged ones
            while import_start < len(lines) and lines[import_start].strip() and 'import' in lines[import_start]:
                lines.pop(import_start)
            
            # Insert merged imports
            for import_line in sorted(all_imports):
                lines.insert(import_start, import_line)
                import_start += 1
        
        return lines
    
    def _validate_syntax(self, code: str) -> bool:
        """Validate Python syntax"""
        try:
            ast.parse(code)
            return True
        except SyntaxError:
            return False
    
    def unify_suggestions(self, original_file: str, suggestions_files: List[str]) -> UnificationResult:
        """Main method to unify AI suggestions from multiple files"""
        self.logger.info(f"Unifying suggestions for {original_file}")
        
        # Read original code
        try:
            with open(original_file, 'r', encoding='utf-8') as f:
                original_code = f.read()
        except Exception as e:
            self.logger.error(f"Failed to read original file {original_file}: {e}")
            return UnificationResult(
                unified_code="",
                applied_edits=[],
                conflicts=[],
                warnings=[f"Failed to read original file: {e}"],
                success=False
            )
        
        # Parse all suggestions
        all_edits = []
        for suggestions_file in suggestions_files:
            edits = self.parse_ai_suggestions(suggestions_file)
            all_edits.extend(edits)
        
        if not all_edits:
            self.logger.warning("No edits found in suggestion files")
            return UnificationResult(
                unified_code=original_code,
                applied_edits=[],
                conflicts=[],
                warnings=["No edits found"],
                success=True
            )
        
        # Detect conflicts
        conflicts = self.detect_conflicts(all_edits)
        self.logger.info(f"Found {len(conflicts)} conflicts")
        
        # Resolve conflicts
        resolved_conflicts = self.resolve_conflicts(conflicts)
        
        # Apply edits
        result = self.apply_edits(original_code, all_edits, resolved_conflicts)
        
        self.logger.info(f"Applied {len(result.applied_edits)} edits successfully")
        return result


def main():
    """Command line interface for the AI Code Unifier"""
    parser = argparse.ArgumentParser(description="Unify AI model suggestions and edits")
    parser.add_argument("original_file", help="Path to the original file")
    parser.add_argument("suggestions_files", nargs="+", help="Paths to suggestion JSON files")
    parser.add_argument("--strategy", choices=[s.value for s in MergeStrategy], 
                       default=MergeStrategy.SMART.value, help="Merge strategy to use")
    parser.add_argument("--output", "-o", help="Output file path (default: original_file.unified)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger("ai_unifier").setLevel(logging.DEBUG)
    
    # Create unifier
    strategy = MergeStrategy(args.strategy)
    unifier = AICodeUnifier(strategy)
    
    # Unify suggestions
    result = unifier.unify_suggestions(args.original_file, args.suggestions_files)
    
    # Output results
    output_file = args.output or f"{args.original_file}.unified"
    
    if result.success:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(result.unified_code)
        print(f"Successfully unified code written to {output_file}")
    else:
        print("Failed to unify code. Check warnings:")
        for warning in result.warnings:
            print(f"  - {warning}")
        sys.exit(1)
    
    # Print summary
    print(f"\nSummary:")
    print(f"  Applied edits: {len(result.applied_edits)}")
    print(f"  Conflicts found: {len(result.conflicts)}")
    print(f"  Warnings: {len(result.warnings)}")
    
    if result.conflicts:
        print(f"\nConflicts:")
        for conflict in result.conflicts:
            print(f"  - {conflict.description}")
            if conflict.resolution:
                print(f"    Resolution: {conflict.resolution}")


if __name__ == "__main__":
    main()