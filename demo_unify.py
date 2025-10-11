#!/usr/bin/env python3
"""
Demo script showing how to use the AI Code Unifier
"""

import subprocess
import sys
from pathlib import Path


def run_demo():
    """Run a demonstration of the AI Code Unifier"""
    print("🤖 AI Code Unifier Demo")
    print("=" * 50)
    
    # Check if the unifier exists
    unifier_path = Path("ai_unifier.py")
    if not unifier_path.exists():
        print("❌ ai_unifier.py not found!")
        return
    
    # Check if example files exist
    original_file = Path("hypervisor_manager/menu.py")
    suggestion_files = [
        "example_suggestions_model1.json",
        "example_suggestions_model2.json", 
        "example_suggestions_model3.json",
        "example_suggestions_model4.json"
    ]
    
    missing_files = [f for f in suggestion_files if not Path(f).exists()]
    if missing_files:
        print(f"❌ Missing suggestion files: {missing_files}")
        return
    
    if not original_file.exists():
        print(f"❌ Original file not found: {original_file}")
        return
    
    print(f"📁 Original file: {original_file}")
    print(f"📄 Suggestion files: {len(suggestion_files)}")
    print()
    
    # Run the unifier with different strategies
    strategies = ["conservative", "aggressive", "smart"]
    
    for strategy in strategies:
        print(f"🔄 Testing {strategy} strategy...")
        
        cmd = [
            "python3", "ai_unifier.py",
            "--strategy", strategy,
            "--output", f"menu_{strategy}.py",
            "--verbose",
            str(original_file)
        ] + suggestion_files
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                print(f"✅ {strategy} strategy completed successfully")
                print(f"   Output: menu_{strategy}.py")
                
                # Show summary
                lines = result.stdout.split('\n')
                for line in lines:
                    if "Applied edits:" in line or "Conflicts found:" in line or "Warnings:" in line:
                        print(f"   {line.strip()}")
            else:
                print(f"❌ {strategy} strategy failed")
                print(f"   Error: {result.stderr}")
                
        except subprocess.TimeoutExpired:
            print(f"⏰ {strategy} strategy timed out")
        except Exception as e:
            print(f"❌ Error running {strategy} strategy: {e}")
        
        print()
    
    # Show file sizes for comparison
    print("📊 File size comparison:")
    original_size = original_file.stat().st_size
    print(f"   Original: {original_size} bytes")
    
    for strategy in strategies:
        output_file = Path(f"menu_{strategy}.py")
        if output_file.exists():
            size = output_file.stat().st_size
            diff = size - original_size
            print(f"   {strategy.capitalize()}: {size} bytes ({diff:+d})")
    
    print()
    print("🎉 Demo completed!")
    print("\nTo review the results:")
    print("   - Check the generated .py files")
    print("   - Compare with the original file")
    print("   - Review any conflicts or warnings")


if __name__ == "__main__":
    run_demo()