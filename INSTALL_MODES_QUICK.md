# Installation Modes - Quick Guide

**30 seconds to choose the right installation mode.**

---

## 🎯 Simple Decision Tree

```
Do you need a GUI desktop immediately?
│
├─ YES ──→ Is your internet fast (>50 Mbps)?
│          │
│          ├─ YES ──→ 🎯 STANDARD MODE
│          │          30 min, 3GB, everything included
│          │
│          └─ NO ───→ ⚡ FAST MODE (Recommended)
│                     15 min, 2GB, same features, faster downloads
│
└─ NO ───→ 🚀 MINIMAL MODE
           13 min, 1.5GB, console-only (add GUI later)
```

---

## 📊 At a Glance

### 🎯 Standard
- **Time:** 30 minutes
- **Size:** 3 GB
- **Includes:** GNOME, hardened kernel, all tools
- **Best for:** First-time install, good internet
- **Tradeoff:** Slower but complete

### ⚡ Fast ⭐ (Most Popular)
- **Time:** 15 minutes (50% faster)
- **Size:** 2 GB (33% less)
- **Includes:** Everything in Standard
- **Best for:** Most users
- **Tradeoff:** None! Same result, faster

### 🚀 Minimal
- **Time:** 13 minutes (60% faster)
- **Size:** 1.5 GB (50% less)
- **Includes:** Core VM management only
- **Best for:** Headless servers, slow internet
- **Tradeoff:** No GUI initially (add later in 10 min)

---

## ⚡ What "Fast" Actually Does

**NOT removed:** Nothing! You get everything.

**Changed:**
- Downloads: 1 connection → 25 parallel connections
- Build: Single-threaded → All CPU cores
- HTTP: Version 1 → Version 2
- Cache: Standard → Optimized

**Result:** 2x faster, same final system.

---

## 🚀 What "Minimal" Removes

**Still Included:**
- ✅ VM management (QEMU, KVM, libvirt)
- ✅ Console menu (full TUI)
- ✅ Security hardening
- ✅ Automation (health, backups, updates)
- ✅ All scripts and docs

**NOT Initially Included:**
- ❌ GNOME desktop (~500 MB)
- ❌ Hardened kernel (uses standard)
- ❌ virt-manager GUI
- ❌ Some monitoring tools

**Can add back:** Any feature, anytime, ~10 minutes.

---

## 💡 Quick Recommendations

| Your Situation | Use This |
|----------------|----------|
| 😊 First time, unsure | **Fast** |
| 🏠 Home lab, good internet | **Fast** |
| 💼 Production server with GUI | **Fast** |
| 🖥️ Headless server | **Minimal** |
| 🌐 Slow internet (<10 Mbps) | **Minimal** |
| 🧪 Testing/development | **Minimal** |
| 📦 Deploying to many systems | **Minimal** |

**When in doubt: Use Fast mode** ⚡

---

## 📝 One-Line Summary

- **Standard:** "Everything, takes time"
- **Fast:** "Everything, 2x faster" ⭐
- **Minimal:** "Essentials, 2.3x faster"

---

## 🔄 Can I Change Later?

**Yes!** NixOS makes it safe and easy.

```bash
# Minimal → Add GUI (10 min)
echo '{ hypervisor.gui.enableAtBoot = true; }' | \
  sudo tee /var/lib/hypervisor/configuration/enable-gui.nix
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"

# Any → Remove GUI (instant)
sudo rm /var/lib/hypervisor/configuration/enable-gui.nix
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
```

---

## ❓ FAQ (Ultra-Brief)

**Q: Is Fast mode less secure?**  
A: No. Identical security to Standard.

**Q: Does Minimal skip automation?**  
A: No. Health checks and backups included.

**Q: Should I use Standard ever?**  
A: Only if you specifically don't want optimizations (rare).

**Q: Best mode for production?**  
A: Fast (if GUI needed) or Minimal (if headless).

---

## 🎯 Bottom Line

**95% of users should choose: Fast mode** ⚡

It's faster, uses less bandwidth, and produces the exact same system as Standard.

Only choose Minimal if you:
- Don't need GUI immediately
- Have very slow internet
- Are deploying to many systems

---

**See [INSTALL_MODES.md](INSTALL_MODES.md) for detailed comparison.**

**Hyper-NixOS v2.0** | © 2024-2025 MasterofNull
