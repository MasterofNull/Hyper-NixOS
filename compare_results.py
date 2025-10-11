#!/usr/bin/env python3
"""
Simple tool to compare the results of different unification strategies
"""

import difflib
from pathlib import Path


def compare_files():
    """Compare the unified files with the original"""
    original = Path("hypervisor_manager/menu.py")
    strategies = ["conservative", "aggressive", "smart"]
    
    print("🔍 AI Code Unifier - Results Comparison")
    print("=" * 60)
    
    if not original.exists():
        print("❌ Original file not found!")
        return
    
    with open(original, 'r') as f:
        original_lines = f.readlines()
    
    print(f"📄 Original file: {len(original_lines)} lines")
    print()
    
    for strategy in strategies:
        output_file = Path(f"menu_{strategy}.py")
        if not output_file.exists():
            print(f"❌ {strategy} output not found!")
            continue
            
        with open(output_file, 'r') as f:
            unified_lines = f.readlines()
        
        print(f"🔄 {strategy.upper()} Strategy Results:")
        print(f"   Lines: {len(unified_lines)} ({len(unified_lines) - len(original_lines):+d})")
        
        # Count changes
        diff = list(difflib.unified_diff(
            original_lines, unified_lines,
            fromfile="original", tofile=f"{strategy}",
            lineterm=""
        ))
        
        added = sum(1 for line in diff if line.startswith('+') and not line.startswith('+++'))
        removed = sum(1 for line in diff if line.startswith('-') and not line.startswith('---'))
        
        print(f"   Changes: +{added} -{removed}")
        
        # Show first few significant changes
        print("   Key changes:")
        significant_changes = [line for line in diff if line.startswith(('+', '-')) and not line.startswith(('+++', '---'))][:5]
        for change in significant_changes:
            prefix = "   " + ("✅" if change.startswith('+') else "❌")
            content = change[1:].strip()
            if content and not content.startswith('#'):
                print(f"{prefix} {content[:60]}{'...' if len(content) > 60 else ''}")
        
        print()


if __name__ == "__main__":
    compare_files()