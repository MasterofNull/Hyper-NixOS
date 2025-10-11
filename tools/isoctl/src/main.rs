use anyhow::{Context, Result};
use clap::Parser;
use indicatif::{ProgressBar, ProgressStyle};
use reqwest::{Client, Url};
use sha2::{Digest, Sha256};
use std::{fs, io::Write, path::PathBuf};

#[derive(Parser, Debug)]
#[command(author, version, about)]
struct Args {
    #[arg(long)]
    url: String,
    #[arg(long)]
    out: PathBuf,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();
    let url = Url::parse(&args.url).context("invalid URL")?;
    let client = Client::builder()
        .use_rustls_tls()
        .https_only(true)
        .build()?;

    let resp = client.get(url).send().await?.error_for_status()?;
    let len = resp.content_length().unwrap_or(0);
    let pb = ProgressBar::new(len);
    pb.set_style(
        ProgressStyle::with_template("{bar:40.cyan/blue} {bytes}/{total_bytes} {eta}").unwrap(),
    );

    let mut hasher = Sha256::new();
    let mut file = fs::File::create(&args.out)?;
    let mut stream = resp.bytes_stream();
    use futures_util::StreamExt;
    while let Some(chunk) = stream.next().await {
        let chunk = chunk?;
        hasher.update(&chunk);
        file.write_all(&chunk)?;
        pb.inc(chunk.len() as u64);
    }
    pb.finish_and_clear();

    let hash = hasher.finalize();
    println!("sha256:{}", hex::encode(hash));
    Ok(())
}
