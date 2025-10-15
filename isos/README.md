# ISO Storage Directory

**Purpose**: Storage location for operating system ISO images used for VM installation

**Usage**:
- Place ISO files here for easy VM creation
- Referenced by VM creation wizards and scripts
- Default location: `/var/lib/hypervisor/isos` (system)
- Development location: `/workspace/isos` (repository)

**Supported ISO Types**:
- Linux distributions (Ubuntu, Fedora, Debian, etc.)
- Windows installation media
- Specialty operating systems
- Custom boot images

**Organization**:
```
isos/
├── linux/          # Linux distribution ISOs
├── windows/        # Windows ISOs
├── specialty/      # Other operating systems
└── custom/         # Custom images
```

**Notes**:
- ISOs can be large; ensure adequate storage space
- This directory is intentionally empty in the repository
- Actual ISOs are downloaded/placed by users as needed
- Not tracked in version control (.gitignore)

---

*For VM creation using ISOs, see: `/docs/user-guides/VM_CREATION_GUIDE.md`*
