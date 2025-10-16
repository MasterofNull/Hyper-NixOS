# Python Hypervisor Manager (Legacy)

**Status**: ⚠️ **DEPRECATED** - Not actively maintained

**Purpose**: 
Original Python-based menu system for VM management using curses interface.

**Current State**:
- No longer integrated with main system
- Replaced by enhanced bash-based menu system in `/scripts/menu/`
- Kept for reference and potential future Python integration

**Files**:
- `menu.py` - Main curses-based menu (290 lines)
- `iso_manager.py` - ISO file management
- `network_manager.py` - Network configuration

**Migration Path**:
If you need menu functionality, use:
- `/scripts/menu.sh` - Main menu system (current)
- `/scripts/menu/` - Modular menu components
- `/scripts/create_vm_wizard.sh` - VM creation

**Future Considerations**:
- May be revived for cross-platform Python GUI
- Could serve as basis for web-based management interface
- Reference implementation for API design

**Preservation Reason**:
- Contains well-structured security validation patterns
- Good reference for input sanitization
- May inform future Python-based tools

---

*Last Active: Pre-v2.0*  
*Maintained for: Reference and future integration*
