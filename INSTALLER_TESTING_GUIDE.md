# Installer Testing Guide

Quick guide for testing the installer fixes.

## Quick Tests

### 1. Syntax Check (30 seconds)
```bash
bash -n install.sh
# Expected: No output = success
```

### 2. Local Test (2 minutes)
```bash
# Clone repo
git clone https://github.com/MasterofNull/Hyper-NixOS.git
cd Hyper-NixOS

# Run installer locally
sudo ./install.sh

# Expected:
# - Menu appears immediately
# - Input is accepted on Enter press
# - Download proceeds smoothly
```

### 3. Remote Test (2 minutes)
```bash
# Run via curl (most common method)
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash

# Expected:
# - Pre-flight checks pass
# - Menu appears
# - Type "1" and press Enter
# - Input accepted immediately (not after 50s)
# - Download starts and completes
```

### 4. Non-Interactive Test (1 minute)
```bash
# Test with no terminal
HYPER_INSTALL_METHOD=tarball curl -sSL ... | sudo -E bash < /dev/null

# Expected:
# - Auto-detects non-interactive mode
# - Uses default option (tarball)
# - Clear message about using default
# - Download proceeds
```

## What to Look For

### ✓ Good Signs
- Input responds immediately when Enter is pressed
- Progress bar displays during download
- Download completes with success message
- File size shown (should be ~400MB)
- Clear, helpful messages

### ✗ Problem Signs
- "No input received (timeout or EOF)" when you DID provide input
- "Download failed" on first attempt despite good network
- Waiting 50 seconds for input to be accepted
- Multiple retry attempts for download
- Missing or corrupted files

## Debug Mode

Enable detailed logging:
```bash
DEBUG=1 curl -sSL ... | sudo -E bash

# Check logs
sudo cat /var/log/hyper-nixos-installer/debug.log
sudo cat /var/log/hyper-nixos-installer/install.log
```

## Common Issues and Solutions

### Issue: "No input received" even when typing
**Cause**: `/dev/tty` not accessible with sudo
**Fix**: Now automatically detected and handled ✓

### Issue: Download keeps failing
**Cause**: Complex progress parsing failing
**Fix**: Simplified to use native curl/wget progress ✓

### Issue: Hangs at input prompt
**Cause**: Read not detecting Enter key
**Fix**: Improved read handling with proper error capture ✓

## Expected Timing

- Pre-flight checks: ~5 seconds
- Input prompt: Immediate response on Enter
- Tarball download: ~30-120 seconds (depends on connection)
- Extraction: ~10-30 seconds
- Total: ~2-5 minutes for full installer

## Testing Checklist

For maintainers testing before release:

- [ ] Syntax validation passes
- [ ] Local installation works
- [ ] Remote (curl) installation works
- [ ] Non-interactive mode works
- [ ] Input responds immediately
- [ ] Download completes successfully
- [ ] Progress display works
- [ ] Error messages are clear
- [ ] Logs are created and useful
- [ ] Works with sudo
- [ ] Works without sudo (for non-root parts)

## Regression Testing

Test these scenarios didn't break:

- [ ] Git clone (HTTPS) method still works
- [ ] Git clone (SSH) method still works  
- [ ] Git clone (Token) method still works
- [ ] Resume from previous state works
- [ ] Error recovery works
- [ ] Log files created properly

## Performance Benchmarks

Expected performance (with good internet):

| Operation | Time | Notes |
|-----------|------|-------|
| Pre-flight checks | 3-5s | Network connectivity, disk space |
| Input handling | <1s | Should be immediate |
| Tarball download (405MB) | 30-120s | Depends on connection speed |
| Extraction | 10-30s | Depends on disk speed |
| Total first-time install | 2-5min | Full remote installation |

If times are significantly longer, investigate:
- Network issues (check connectivity)
- Disk I/O issues (check `df`, `iostat`)
- CPU issues (check `top`)

## Reporting Issues

If you find problems, provide:

1. **Command used**: Exact curl command or local path
2. **Error output**: Full terminal output
3. **Log files**: Contents of `/var/log/hyper-nixos-installer/*.log`
4. **Environment**:
   - OS/Distribution
   - Network type (home, corporate, VPN, etc.)
   - Running as root or sudo
   - Terminal type
5. **Expected vs actual behavior**

## Success Criteria

The installer is working correctly when:

✓ Input is accepted immediately (no artificial delays)
✓ Downloads complete reliably (no false failures)
✓ Progress is visible and accurate
✓ Error messages are clear and actionable
✓ Non-interactive mode works automatically
✓ All four download methods work
✓ Logs are created and helpful for debugging
✓ Experience is smooth from start to finish
