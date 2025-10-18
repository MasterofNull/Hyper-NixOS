#!/bin/bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: branding.sh
# Purpose: Standardized branding elements for all scripts
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

# Color definitions (compatible with ui.sh)
if [[ -z "${BLUE:-}" ]]; then
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    MAGENTA='\033[0;35m'
    NC='\033[0m' # No Color
    BOLD='\033[1m'
fi

# Project information
HYPER_NIXOS_VERSION="1.0.0"
HYPER_NIXOS_AUTHOR="MasterofNull"
HYPER_NIXOS_COPYRIGHT="© 2024-2025 MasterofNull"
HYPER_NIXOS_LICENSE="MIT License"
HYPER_NIXOS_REPO="https://github.com/MasterofNull/Hyper-NixOS"

# ASCII Art Banner (Large)
show_banner_large() {
    echo -e "${BLUE}"
    cat << 'EOF'
╦ ╦┬ ┬┌─┐┌─┐┬─┐   ╔╗╔┬─┐ ┬╔═╗╔═╗
╠═╣└┬┘├─┘├┤ ├┬┘───║║║│┌┴┬┘║ ║╚═╗
╩ ╩ ┴ ┴  └─┘┴└─   ╝╚╝┴┴ └─╚═╝╚═╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}Next-Generation Virtualization Platform${NC}"
    echo -e "${MAGENTA}v${HYPER_NIXOS_VERSION}${NC} | ${HYPER_NIXOS_COPYRIGHT}"
    echo ""
}

# ASCII Art Banner (Compact)
show_banner_compact() {
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}Hyper-NixOS${NC} ${CYAN}v${HYPER_NIXOS_VERSION}${NC}                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${MAGENTA}Next-Gen Virtualization Platform${NC}     ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

# Mini banner (single line)
show_banner_mini() {
    echo -e "${BLUE}═══${NC} ${BOLD}Hyper-NixOS${NC} ${CYAN}v${HYPER_NIXOS_VERSION}${NC} ${BLUE}═══${NC}"
    echo ""
}

# Footer with credits
show_footer() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Hyper-NixOS ${HYPER_NIXOS_COPYRIGHT}"
    echo -e "Licensed under ${HYPER_NIXOS_LICENSE}"
    echo -e "Project: ${CYAN}${HYPER_NIXOS_REPO}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Compact footer
show_footer_compact() {
    echo ""
    echo -e "${BLUE}Hyper-NixOS${NC} ${HYPER_NIXOS_COPYRIGHT} | ${HYPER_NIXOS_LICENSE}"
}

# Mini header for less prominent branding
show_mini_header() {
    echo -e "${BLUE}Hyper-NixOS${NC} v${HYPER_NIXOS_VERSION} | ${HYPER_NIXOS_COPYRIGHT}"
    echo ""
}

# License notice (full)
show_license_notice() {
    cat << EOF

${BOLD}LICENSE NOTICE${NC}
━━━━━━━━━━━━━━
This software is part of Hyper-NixOS
${HYPER_NIXOS_COPYRIGHT}

Licensed under the ${HYPER_NIXOS_LICENSE}
You may use, modify, and distribute this software
under the terms of the MIT License.

See LICENSE file for full details: ${HYPER_NIXOS_REPO}/LICENSE

${BOLD}MIT License Summary:${NC}
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

EOF
}

# Credits screen
show_credits() {
    clear
    show_banner_large

    cat << EOF
${BOLD}PROJECT CREDITS${NC}

${CYAN}Primary Author & Architect:${NC}
  ${HYPER_NIXOS_AUTHOR}
  • Project Creator & Lead Developer
  • Design Philosophy & Architecture
  • Initial Implementation

${CYAN}AI Development Assistant:${NC}
  Claude (Anthropic)
  • Code generation and refactoring
  • Documentation assistance
  • Pattern implementation

${CYAN}Design Philosophy - Three Pillars:${NC}
  1. Ease of Use - Minimize friction at all stages
  2. Security & Organization - Security-first with clean structure
  3. Learning Ethos - Functional AND educational

${CYAN}Built With:${NC}
  • NixOS 24.05+ - Declarative system configuration
  • KVM/QEMU - Hardware virtualization
  • libvirt - VM management framework
  • Bash - System scripting
  • Python - Security and monitoring tools
  • Rust - Performance-critical CLI tools
  • Go - GraphQL API backend

${CYAN}License:${NC}
  ${HYPER_NIXOS_LICENSE}
  See LICENSE file for details

${CYAN}Contributing:${NC}
  Visit ${CYAN}${HYPER_NIXOS_REPO}${NC}
  Read ${CYAN}docs/CONTRIBUTING.md${NC} for guidelines

${CYAN}Support:${NC}
  Issues: ${CYAN}${HYPER_NIXOS_REPO}/issues${NC}
  Discussions: ${CYAN}${HYPER_NIXOS_REPO}/discussions${NC}
  Documentation: ${CYAN}/usr/share/doc/hypervisor/${NC}

${CYAN}Special Thanks:${NC}
  • NixOS Community - Foundation and inspiration
  • KVM/QEMU Project - Virtualization technology
  • libvirt Project - Management framework
  • All contributors and users

EOF
    show_footer
}

# Version information
show_version() {
    show_banner_compact
    echo -e "${BOLD}Version Information${NC}"
    echo -e "Version: ${CYAN}${HYPER_NIXOS_VERSION}${NC}"
    echo -e "Author: ${HYPER_NIXOS_AUTHOR}"
    echo -e "License: ${HYPER_NIXOS_LICENSE}"
    echo -e "Repository: ${CYAN}${HYPER_NIXOS_REPO}${NC}"
    echo ""
}

# Simple copyright line
show_copyright() {
    echo -e "${HYPER_NIXOS_COPYRIGHT} | ${HYPER_NIXOS_LICENSE}"
}

# Export all functions
export -f show_banner_large
export -f show_banner_compact
export -f show_banner_mini
export -f show_footer
export -f show_footer_compact
export -f show_mini_header
export -f show_license_notice
export -f show_credits
export -f show_version
export -f show_copyright

# Export variables
export HYPER_NIXOS_VERSION
export HYPER_NIXOS_AUTHOR
export HYPER_NIXOS_COPYRIGHT
export HYPER_NIXOS_LICENSE
export HYPER_NIXOS_REPO
