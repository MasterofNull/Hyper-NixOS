use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde::Deserialize;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Deserialize)]
struct Network { bridge: Option<String> }
#[derive(Debug, Deserialize)]
struct Audio { model: Option<String> }
#[derive(Debug, Deserialize)]
struct Video { heads: Option<u32> }
#[derive(Debug, Deserialize)]
struct LookingGlass { enable: Option<bool>, size_mb: Option<u32> }

#[derive(Debug, Deserialize)]
struct Profile {
    name: String,
    cpus: u32,
    memory_mb: u32,
    disk_gb: Option<u32>,
    iso_path: Option<String>,
    network: Option<Network>,
    cpu_pinning: Option<Vec<u32>>,
    hugepages: Option<bool>,
    audio: Option<Audio>,
    video: Option<Video>,
    looking_glass: Option<LookingGlass>,
    hostdevs: Option<Vec<String>>,
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
    let mut xml = String::new();
    xml.push_str(&format!("<domain type='kvm'>\n  <name>{}</name>\n  <memory unit='MiB'>{}</memory>\n  <vcpu placement='static'>{}</vcpu>\n  <os>\n    <type arch='x86_64' machine='q35'>hvm</type>\n    <loader readonly='yes' type='pflash'>/run/current-system/sw/share/OVMF/OVMF_CODE.fd</loader>\n    <nvram>/var/lib/hypervisor/{}.OVMF_VARS.fd</nvram>\n  </os>\n  <features>\n    <acpi/>\n    <apic/>\n  </features>\n  <cpu mode='host-passthrough'/>\n", name, mem, cpus, name));
    if p.hugepages.unwrap_or(false) {
        xml.push_str("  <memoryBacking>\n    <hugepages/>\n  </memoryBacking>\n");
    }
    if let Some(pin) = p.cpu_pinning.as_ref() {
        xml.push_str("  <cputune>\n");
        for (i, host_cpu) in pin.iter().enumerate() {
            xml.push_str(&format!("    <vcpupin vcpu='{}' cpuset='{}'/>\n", i, host_cpu));
        }
        xml.push_str("  </cputune>\n");
    }
    xml.push_str("  <devices>\n    <emulator>/run/current-system/sw/bin/qemu-system-x86_64</emulator>\n");
    if let Some(disk_gb) = p.disk_gb { let _ = disk_gb; }
    xml.push_str("    <disk type='file' device='disk'>\n      <driver name='qemu' type='qcow2'/>\n      <source file='REPLACEME_QCOW'/>\n      <target dev='vda' bus='virtio'/>\n    </disk>\n");
    if let Some(iso) = p.iso_path.as_ref() {
        xml.push_str(&format!("    <disk type='file' device='cdrom'>\n      <source file='{}'/>\n      <target dev='sda' bus='sata'/>\n      <readonly/>\n    </disk>\n", escape(iso)));
    }
    xml.push_str("    <graphics type='spice' autoport='yes' listen='127.0.0.1'/>\n");
    let heads = p.video.as_ref().and_then(|v| v.heads).unwrap_or(1);
    xml.push_str(&format!("    <video>\n      <model type='virtio' heads='{}'/>\n    </video>\n", heads));
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
        xml.push_str("    <interface type='user'>\n      <model type='virtio'/>\n    </interface>\n");
    }
    if let Some(hostdevs) = p.hostdevs.as_ref() {
        for bdf in hostdevs {
            if !bdf.chars().all(|c| c.is_ascii_hexdigit() || c == ':' || c == '.') { continue; }
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
