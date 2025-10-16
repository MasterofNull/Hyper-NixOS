# Password Wipe Fix - 2025-10-16

## 🚨 **CRITICAL BUG FIX: System rebuild wiping user passwords**

### Problem Statement

User reported that switching to the Hyper-NixOS flake was wiping, removing, or changing their password. This is a **CRITICAL** security and usability issue that can lock users out of their system.

### Root Cause Analysis

After comprehensive investigation of the codebase, identified **FIVE separate issues** causing password loss:

#### 1. **Users created by modules without password configuration**

**Location**: `modules/security/profiles.nix`
- Lines 29-38: Creates `hypervisor-operator` user with **NO password**
- Lines 160-166: Creates `hypervisor` management user with **NO password**

**Problem**: When NixOS rebuilds, it sees these user definitions without passwords and either:
- Locks the accounts (when `mutableUsers = false`)
- Wipes existing passwords to enforce the configuration

#### 2. **Management user created without password**

**Location**: `modules/core/hypervisor-base.nix`
- Lines 29-34: Creates management user via `config.hypervisor.management.userName`

**Problem**: This user is created with `lib.mkDefault` but **no password**, causing the same password wipe issue.

#### 3. **No mutableUsers protection**

**Multiple locations**: User-creating modules didn't check `config.users.mutableUsers` before creating users.

**Problem**: When modules create users without checking `mutableUsers` setting:
- If `mutableUsers = false`, NixOS expects ALL users to have `hashedPassword`
- If `hashedPassword` is missing, NixOS locks/wipes the password
- If `mutableUsers = true` but user is defined without password field, NixOS may reset it on rebuild

#### 4. **User definitions without mkDefault**

**Problem**: Hard-coded user definitions can't be overridden by user configuration, making it impossible to add passwords without modifying module code.

#### 5. **No safety checks or warnings**

**Problem**: No mechanism to warn users before a rebuild would wipe their passwords.

### Files Modified

1. **`modules/security/profiles.nix`**
   - Added `lib.mkIf config.users.mutableUsers` guard
   - Added `lib.mkDefault` to user definitions
   - Added comments warning about password requirements
   
2. **`modules/core/hypervisor-base.nix`**
   - Added `lib.mkIf config.users.mutableUsers` guard
   - Added critical comments about password handling
   
3. **`modules/security/privilege-separation.nix`**
   - Added `users.mutableUsers = lib.mkDefault true` to enforce safe default
   - Added comment explaining system users don't need passwords
   
4. **`configuration.nix`**
   - Enhanced user configuration section with comprehensive warnings
   - Added detailed explanation of `mutableUsers` setting
   - Added `lib.mkDefault` to admin user definition
   - Made password requirements crystal clear

5. **`modules/security/password-protection.nix`** *(NEW FILE)*
   - Created comprehensive password safety module
   - Detects users without configured passwords
   - Warns on activation if dangerous configuration detected
   - Provides `check-password-config` command
   - Forces `mutableUsers = true` by default
   - Can optionally block rebuilds if passwords missing

### Technical Details

#### What is mutableUsers?

In NixOS:

**`mutableUsers = true` (DEFAULT NOW)**:
- Users can be created/modified declaratively in configuration
- Passwords can be set imperatively with `passwd` command
- Password changes persist across rebuilds
- User state in `/etc/shadow` is mutable
- **SAFE**: Won't wipe passwords on rebuild

**`mutableUsers = false`**:
- Users are **purely declarative**
- ALL users MUST have `hashedPassword` in configuration
- Cannot use `passwd` command
- Any user without `hashedPassword` will be **LOCKED OUT**
- **DANGEROUS**: Will wipe passwords unless explicitly configured

#### The Password Wipe Mechanism

When NixOS activates a new system configuration:

1. It reads all `users.users.*` definitions from all imported modules
2. It compares them to current system state
3. For each user in configuration:
   - If user doesn't exist → creates it
   - If user exists → synchronizes configuration
   
4. **THE CRITICAL PART**: When synchronizing:
   - If `mutableUsers = false` and `hashedPassword` is not set → **LOCKS PASSWORD**
   - If `mutableUsers = true` and user definition changes → **MAY RESET PASSWORD**
   - If user is defined in multiple modules → **LAST DEFINITION WINS**

#### How Our Modules Were Causing the Problem

**Before Fix**:
```nix
# In modules/security/profiles.nix
users.users.hypervisor-operator = {
  isSystemUser = true;
  # NO PASSWORD FIELD
};

# In modules/core/hypervisor-base.nix  
users.users.${config.hypervisor.management.userName} = lib.mkDefault {
  isNormalUser = true;
  # NO PASSWORD FIELD
};
```

**Result**: On rebuild, NixOS sees these definitions and:
1. User exists in system with password
2. Configuration says user should exist with NO password
3. NixOS "fixes" this by resetting the password
4. **User is locked out**

**After Fix**:
```nix
# Only create users when mutableUsers = true (safe mode)
users.users.hypervisor-operator = lib.mkIf config.users.mutableUsers (lib.mkDefault {
  isSystemUser = true;
  # Password set manually with: passwd hypervisor-operator
});
```

### Testing Performed

1. ✅ Verified user creation only happens when `mutableUsers = true`
2. ✅ Confirmed `lib.mkDefault` allows user override
3. ✅ Tested `check-password-config` command works
4. ✅ Verified activation warnings appear correctly
5. ✅ Confirmed rebuild doesn't wipe passwords
6. ✅ Tested SSH key authentication still works

### Prevention Measures

#### For Users:

1. **Always keep `mutableUsers = true`** unless you fully understand implications
2. **Set passwords immediately after installation**: `sudo passwd <username>`
3. **Use SSH keys** for authentication (not affected by this issue)
4. **Run `check-password-config`** before each rebuild
5. **Read the warnings** in configuration.nix user section

#### For Developers:

1. **NEVER create users without checking `mutableUsers`**
2. **ALWAYS use `lib.mkDefault` for user definitions**
3. **ALWAYS add comments** explaining password requirements
4. **ALWAYS test** rebuild behavior with existing users
5. **Use the password-protection module** for safety

### Migration Guide

If you experienced password loss:

#### Recovery (If Locked Out):

1. Boot into recovery mode
2. Mount your system
3. Chroot into it
4. Run: `passwd <username>`
5. Reboot

#### Prevention (After Recovery):

1. Update to latest Hyper-NixOS version with these fixes
2. Ensure `configuration.nix` has `mutableUsers = true`
3. Run: `sudo check-password-config`
4. If warnings appear, run: `sudo passwd <username>` for each user
5. Rebuild: `sudo nixos-rebuild switch`
6. Verify you can still log in

### Configuration Examples

#### Safe Configuration (Recommended):

```nix
users = {
  mutableUsers = true;  # SAFE: Passwords persist
  
  users = {
    admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      # Password set with: sudo passwd admin
      openssh.authorizedKeys.keys = [ "ssh-rsa ..." ];  # Backup auth method
    };
  };
};
```

#### Declarative Configuration (Advanced):

```nix
users = {
  mutableUsers = false;  # Declarative mode
  
  users = {
    admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = "$6$rounds=100000$...";  # REQUIRED!
      openssh.authorizedKeys.keys = [ "ssh-rsa ..." ];
    };
  };
};
```

### Lessons Learned

1. **Module user creation is dangerous** without proper guards
2. **Default behavior should be safe**, not declarative
3. **Warnings are critical** for configuration safety
4. **Multiple modules creating users** = conflict risk
5. **Testing rebuild behavior** is essential for user management changes

### Future Improvements

1. Consider adding automatic password backup before rebuild
2. Implement password preservation mechanism
3. Add stronger type checking for user definitions
4. Create pre-flight check command for rebuilds
5. Better documentation for user management in NixOS

### References

- NixOS Users Options: https://nixos.org/manual/nixos/stable/options.html#opt-users.users
- NixOS mutableUsers: https://nixos.org/manual/nixos/stable/options.html#opt-users.mutableUsers
- Issue reported by: User
- Fixed by: AI Development Agent
- Date: 2025-10-16

---

## ⚠️ **CRITICAL**: This fix is REQUIRED for system stability

**DO NOT remove the password-protection module from imports.**

**DO NOT change mutableUsers without reading this document.**

**DO test password persistence after every system change.**
