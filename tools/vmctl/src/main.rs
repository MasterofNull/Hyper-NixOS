use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde::Deserialize;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Deserialize)]
struct Network {
    bridge: Option<String>,
}
#[derive(Debug, Deserialize)]
struct Audio {
    model: Option<String>,
}
#[derive(Debug, Deserialize)]
struct Video {
    heads: Option<u32>,
}
#[derive(Debug, Deserialize)]
struct LookingGlass {
    enable: Option<bool>,
    size_mb: Option<u32>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct CpuFeatures {
    shstk: Option<bool>,
    ibt: Option<bool>,
    avic: Option<bool>,
    secure_avic: Option<bool>,
    sev: Option<bool>,
    sev_es: Option<bool>,
    sev_snp: Option<bool>,
    ciphertext_hiding: Option<bool>,
    secure_tsc: Option<bool>,
    fred: Option<bool>,
    zhaoxin_centaur_leaves: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct MemoryOptions {
    guest_memfd: Option<bool>,
    private: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct Profile {
    name: String,
    cpus: u32,
    memory_mb: u32,
    disk_gb: Option<u32>,
    iso_path: Option<String>,
    arch: Option<String>,
    network: Option<Network>,
    cpu_pinning: Option<Vec<u32>>,
    hugepages: Option<bool>,
    audio: Option<Audio>,
    video: Option<Video>,
    looking_glass: Option<LookingGlass>,
    hostdevs: Option<Vec<String>>,
    cpu_features: Option<CpuFeatures>,
    memory_options: Option<MemoryOptions>,
}

#[derive(Parser, Debug)]
#[command(author, version, about)]
struct Args {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand, Debug)]
enum Cmd {
    GenXml { profile: PathBuf, out: PathBuf },
}

fn escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&apos;")
}

fn gen_xml(p: &Profile) -> String {
    let name = escape(&p.name);
    let cpus = p.cpus;
    let mem = p.memory_mb;
    let arch = p.arch.as_deref().unwrap_or("x86_64");
    let (machine, loader, nvram) = match arch {
        "x86_64" => (
            "q35",
            Some("/run/current-system/sw/share/OVMF/OVMF_CODE.fd"),
            Some(format!("/var/lib/hypervisor/{}.OVMF_VARS.fd", name)),
        ),
        "aarch64" => (
            "virt",
            Some("/run/current-system/sw/share/AAVMF/AAVMF_CODE.fd"),
            Some(format!("/var/lib/hypervisor/{}.AAVMF_VARS.fd", name)),
        ),
        "riscv64" => ("virt", None, None),
        "loongarch64" => ("virt", None, None),
        _ => (
            "q35",
            Some("/run/current-system/sw/share/OVMF/OVMF_CODE.fd"),
            Some(format!("/var/lib/hypervisor/{}.OVMF_VARS.fd", name)),
        ),
    };

    let mut xml = String::new();
    xml.push_str(&format!("<domain type='kvm'>\n  <name>{}</name>\n  <memory unit='MiB'>{}</memory>\n  <vcpu placement='static'>{}</vcpu>\n  <os>\n    <type arch='{}' machine='{}'>hvm</type>\n", name, mem, cpus, escape(arch), machine));
    if let Some(loader_path) = loader {
        xml.push_str(&format!(
            "    <loader readonly='yes' type='pflash'>{}</loader>\n",
            loader_path
        ));
    }
    if let Some(nvram_path) = nvram.as_ref() {
        xml.push_str(&format!("    <nvram>{}</nvram>\n", nvram_path));
    }
    xml.push_str("  </os>\n  <features>\n    <acpi/>\n    <apic/>\n  </features>\n");
    xml.push_str("  <cpu mode='host-passthrough' check='partial'>\n");
    if arch == "x86_64" {
        if p.cpu_features
            .as_ref()
            .and_then(|c| c.shstk)
            .unwrap_or(false)
        {
            xml.push_str("    <feature policy='require' name='shstk'/>\n");
        }
        if p.cpu_features.as_ref().and_then(|c| c.ibt).unwrap_or(false) {
            xml.push_str("    <feature policy='require' name='ibt'/>\n");
        }
        if p.cpu_features
            .as_ref()
            .and_then(|c| c.avic)
            .unwrap_or(false)
        {
            xml.push_str("    <feature policy='require' name='avic'/>\n");
        }
    }
    xml.push_str("  </cpu>\n");
    if p.hugepages.unwrap_or(false)
        || p.memory_options
            .as_ref()
            .and_then(|m| m.guest_memfd)
            .unwrap_or(false)
        || p.memory_options
            .as_ref()
            .and_then(|m| m.private)
            .unwrap_or(false)
    {
        xml.push_str("  <memoryBacking>\n");
        if p.hugepages.unwrap_or(false) {
            xml.push_str("    <hugepages/>\n");
        }
        if p.memory_options
            .as_ref()
            .and_then(|m| m.guest_memfd)
            .unwrap_or(false)
        {
            xml.push_str("    <source type='memfd'/>\n");
        }
        if p.memory_options
            .as_ref()
            .and_then(|m| m.private)
            .unwrap_or(false)
        {
            xml.push_str("    <access mode='private'/>\n");
        }
        xml.push_str("  </memoryBacking>\n");
    }
    if let Some(pin) = p.cpu_pinning.as_ref() {
        xml.push_str("  <cputune>\n");
        for (i, host_cpu) in pin.iter().enumerate() {
            xml.push_str(&format!(
                "    <vcpupin vcpu='{}' cpuset='{}'/>\n",
                i, host_cpu
            ));
        }
        xml.push_str("  </cputune>\n");
    }
    let emulator = match arch {
        "x86_64" => "/run/current-system/sw/bin/qemu-system-x86_64",
        "aarch64" => "/run/current-system/sw/bin/qemu-system-aarch64",
        "riscv64" => "/run/current-system/sw/bin/qemu-system-riscv64",
        "loongarch64" => "/run/current-system/sw/bin/qemu-system-loongarch64",
        _ => "/run/current-system/sw/bin/qemu-system-x86_64",
    };
    xml.push_str(&format!(
        "  <devices>\n    <emulator>{}</emulator>\n",
        emulator
    ));
    if let Some(disk_gb) = p.disk_gb {
        let _ = disk_gb;
    }
    xml.push_str("    <disk type='file' device='disk'>\n      <driver name='qemu' type='qcow2'/>\n      <source file='REPLACEME_QCOW'/>\n      <target dev='vda' bus='virtio'/>\n    </disk>\n");
    if let Some(iso) = p.iso_path.as_ref() {
        xml.push_str(&format!("    <disk type='file' device='cdrom'>\n      <source file='{}'/>\n      <target dev='sda' bus='sata'/>\n      <readonly/>\n    </disk>\n", escape(iso)));
    }
    xml.push_str("    <graphics type='spice' autoport='yes' listen='127.0.0.1'/>\n");
    let heads = p.video.as_ref().and_then(|v| v.heads).unwrap_or(1);
    xml.push_str(&format!(
        "    <video>\n      <model type='virtio' heads='{}'/>\n    </video>\n",
        heads
    ));
    xml.push_str("    <input type='tablet' bus='usb'/>\n");
    if let Some(a) = p.audio.as_ref().and_then(|a| a.model.as_ref()) {
        xml.push_str(&format!("    <sound model='{}'/>\n", escape(a)));
    }
    if let Some(lg) = p.looking_glass.as_ref() {
        if lg.enable.unwrap_or(false) {
            let size = lg.size_mb.unwrap_or(64);
            xml.push_str(&format!("    <shmem name='looking-glass'>\n      <model type='ivshmem-plain'/>\n      <size unit='M'>{}</size>\n    </shmem>\n", size));
        }
    }
    if let Some(bridge) = p.network.as_ref().and_then(|n| n.bridge.as_ref()) {
        xml.push_str(&format!("    <interface type='bridge'>\n      <source bridge='{}'/>\n      <model type='virtio'/>\n    </interface>\n", escape(bridge)));
    } else {
        xml.push_str(
            "    <interface type='user'>\n      <model type='virtio'/>\n    </interface>\n",
        );
    }
    if let Some(hostdevs) = p.hostdevs.as_ref() {
        for bdf in hostdevs {
            if !bdf
                .chars()
                .all(|c| c.is_ascii_hexdigit() || c == ':' || c == '.')
            {
                continue;
            }
            xml.push_str(&format!("    <hostdev mode='subsystem' type='pci' managed='yes'>\n      <source>\n        <address domain='0x{}' bus='0x{}' slot='0x{}' function='0x{}'/>\n      </source>\n    </hostdev>\n",
                &bdf[0..4], &bdf[5..7], &bdf[8..10], &bdf[11..12]));
        }
    }
    xml.push_str("  </devices>\n</domain>\n");
    xml
}

fn main() -> Result<()> {
    let args = Args::parse();
    match args.cmd {
        Cmd::GenXml { profile, out } => {
            let data = fs::read_to_string(&profile).context("reading profile")?;
            let p: Profile = serde_json::from_str(&data).context("parsing profile")?;
            let xml = gen_xml(&p);
            fs::write(&out, xml).context("writing xml")?;
            println!("generated: {}", out.display());
        }
    }
    Ok(())
}
