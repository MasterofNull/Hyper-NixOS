# Security Tips, Tricks, and Workarounds Documentation

This document captures advanced techniques, clever workarounds, and practical tips discovered in the security-focused distribution's codebase.

## Table of Contents
1. [Shell & Command Line Tricks](#shell--command-line-tricks)
2. [Docker Security Patterns](#docker-security-patterns)
3. [Network Security Techniques](#network-security-techniques)
4. [Automation Workarounds](#automation-workarounds)
5. [Security Testing Patterns](#security-testing-patterns)
6. [Resource Management](#resource-management)
7. [Monitoring & Alerting](#monitoring--alerting)
8. [Data Protection](#data-protection)

## Shell & Command Line Tricks

### 1. **SSH with Automatic Mount (sshm)**
**Technique**: Combine SSH connection with automatic SSHFS mounting
```bash
sshm() {
  TARGET_HOST=`echo $@ | choose -f '@' 1 | choose 0`
  if [[ "$@" == *"@"* ]]; then
    TARGET_USER=`echo $@ | choose -f '@' 0 | choose -1`
  else
    TARGET_USER="$USER"
  fi
  
  TARGET_DIR="/home/user/tmp_today/${TARGET_HOST}_mount"
  mkdir -p $TARGET_DIR
  
  sshfs -o uid=`id -u user` -o gid=`id -g user` ${TARGET_USER}@${TARGET_HOST}:/ $TARGET_DIR
  ssh $@
  umount $TARGET_DIR
}
```
**Why it's clever**: Automatically mounts remote filesystem for easy file access during SSH sessions

### 2. **SSH Login Alerts**
**Technique**: Automatic notification on SSH login
```bash
if [[ -n "$SSH_CONNECTION" ]]; then
  screen -adm $HOME/scripts/notify.sh -a -q -m "Login from $SSH_CLIENT"
fi
```
**Security benefit**: Immediate awareness of system access

### 3. **Timestamp Generation**
**Technique**: Consistent timestamp format for files
```bash
now() {
  date +"%Y%m%d_%H%M%S"
}
```
**Use case**: Unique file naming for logs, reports, and backups

### 4. **Content Length Detection for 404 Pages**
**Technique**: Identify 404 page size for directory enumeration
```bash
a.cl() {
  UUID=`uuidgen`
  # Test with random paths to find 404 content length
  curl -sI $1/XXXX${UUID} | grep -i Content-Length | choose 1
  curl -sI $1/XX${UUID} | grep -i Content-Length | choose 1
  # Compare with actual page
  curl -sI $1 | grep -i Content-Length | choose 1
}
```
**Why it's useful**: Helps filter false positives in directory brute-forcing

## Docker Security Patterns

### 1. **Security Check Before Running in Home Directory**
**Workaround**: Prevent accidental exposure of sensitive files
```bash
d.filebrowserhere() {
  # Security measure
  if [[ "`pwd`" == "$HOME" ]]; then
    echo "ERROR: Not running in $HOME .."
    return 1
  fi
  
  docker run --rm --name filebrowser -p 1080:80 -v $(pwd):/srv filebrowser/filebrowser
}
```

### 2. **Docker Volume Caching Pattern**
**Technique**: Check if data exists before regenerating
```bash
a.cloudmapper() {
  if docker volume inspect ${1}-cloudmapper-account-data; then
    while true; do
      echo -n "${1}-cloudmapper-account-data docker volume exists, just serve? [Yn] "
      read yn
      case $yn in
        [Yy]* ) a.cloudmapper-serve $@; break;;
        [Nn]* ) a.cloudmapper-gather $@; a.cloudmapper-serve $@; break;;
        * ) a.cloudmapper-serve $@; break;;
      esac
    done
  else
    a.cloudmapper-gather $@
    a.cloudmapper-serve $@
  fi
}
```
**Benefit**: Saves time by reusing existing analysis results

### 3. **Dynamic Port Replacement**
**Technique**: Modify docker-compose files for custom ports
```bash
d.rengine() {
  cd $HOME/git/pentest-tools/rengine
  cp $HOME/resources/rengine/docker-compose.yml .
  sed -i "s#- 443:443/tcp#- ${PORT_RENGINE}:443/tcp#g" docker-compose.yml
  sudo make up
}
```
**Why it's clever**: Avoids port conflicts by using predefined port variables

### 4. **Container Cleanup Pattern**
**Technique**: Stop containers by name pattern
```bash
d.webtop-kill() {
  docker stop `docker ps -a -q -f name=webtop | choose 0`
}
```

### 5. **Secrets in Docker Commands**
**Technique**: Pass secrets securely to containers
```bash
a.localhostrun-filebrowser() {
  PASSWORD_CLEAR=`pwgen 10`
  echo "Password is $PASSWORD_CLEAR"
  echo -n "$PASSWORD_CLEAR" | qrencode -t UTF8  # QR code for easy mobile access
  
  PASSWORD=`docker run --rm filebrowser/filebrowser hash $PASSWORD_CLEAR`
  docker run --rm -d -p 1080:80 -v $(pwd):/srv filebrowser/filebrowser \
    --password $PASSWORD
}
```

## Network Security Techniques

### 1. **Localhost.run Integration**
**Technique**: Expose local services securely over internet
```bash
a.localhostrun() {
  if [[ "$#" -ne "1" ]]; then
    echo "Specify port number"
  else
    ssh -R 80:localhost:$1 nokey@localhost.run
  fi
}
```
**Use cases**: Quick sharing, webhook testing, demo deployments

### 2. **Terminal Over Web (gotty)**
**Technique**: Share terminal commands via web interface
```bash
a.localhostrun-gotty() {
  TIMESTAMP=`date +%Y%m%d_%H%M%S`
  screen -S ${TIMESTAMP}_testssl -adm gotty --port 9000 $@
  ssh -R 80:localhost:9000 nokey@localhost.run
  screen -S ${TIMESTAMP}_testssl -X quit
}
```

### 3. **Proxy Chromium Instance**
**Technique**: Browser with automatic proxy configuration
```bash
a.cp() {
  chromium --force-device-scale-factor=1.6 --proxy-server='127.0.0.1:8080' $@
}
```
**Use case**: Web testing through Burp Suite or other proxies

### 4. **SMB Server in Current Directory**
**Technique**: Quick file sharing via SMB
```bash
d.smbservehere() {
  docker run --rm -it -p 445:445 -v $(pwd):/share dperson/samba \
    -s "share;/share;yes;no;no;all;none"
}
```

### 5. **Tor Array Deployment**
**Technique**: Multiple Tor instances with incremental ports
```bash
d.tor-array() {
  COUNT=${1:-5}
  for i in $(seq 1 $COUNT); do
    PORT=$((9050 + $i))
    docker run -d --name tor-$i -p 127.0.0.1:$PORT:9050 dperson/torproxy
  done
}
```

## Automation Workarounds

### 1. **Git Update with Cache Check**
**Technique**: Avoid unnecessary git pulls
```bash
function git_update() {
  DIR_ACCESSED=`find $2 -maxdepth 0 -type d -atime -1 2>/dev/null | wc -l`
  
  # Only pull if directory not accessed in last day or forced
  if [[ "$DIR_ACCESSED" == "0" || "$arg_force" == "1" ]]; then
    git clone --depth 1 $1 $2
    cd $2
    git reset --hard
    git pull
    return 0
  fi
  return 1
}
```
**Why it's smart**: Reduces network traffic and speeds up scripts

### 2. **Parallel Tool Execution**
**Technique**: Run multiple scanners simultaneously
```bash
a.bust() {
  # Run multiple tools in parallel
  echo $1 | httpx -silent -json > $HOME/scans/$ASSESSMENT_NAME/httpx.txt &
  docker run --rm redgo katana -u $1 > $HOME/scans/$ASSESSMENT_NAME/katana.txt &
  wait  # Wait for background jobs
  
  # Then run sequential scans
  gobuster dir --url $1 --wordlist /wordlists/english.txt -o gobuster_english.txt &
  gobuster dir --url $1 --wordlist /wordlists/onelistforall.txt -o gobuster_onelistforall.txt &
}
```

### 3. **Notification on Completion**
**Technique**: Background notifications for long-running tasks
```bash
screen -adm $HOME/scripts/notify.sh -a -q -m "SQLi scan finished for $1"
```

### 4. **Temporary File Management**
**Technique**: Use UUIDs for temp files to avoid collisions
```bash
TMP_FILE=`uuidgen | choose -f '-' -1`
echo $1 | hakrawler > /tmp/sqli_${TMP_FILE}
```

## Security Testing Patterns

### 1. **SQL Injection Testing Pipeline**
**Technique**: Chain tools for comprehensive SQLi testing
```bash
a.sqli() {
  TMP_FILE=`uuidgen | choose -f '-' -1`
  
  echo $1 |\
  hakrawler > /tmp/sqli_${TMP_FILE} && \
  cat /tmp/sqli_${TMP_FILE} |\
  echo $1 | docker run -i --rm redgo waybackurls --no-subs |\
  grep -o "http[^ ]*" > /tmp/sqli_filter_urls_${TMP_FILE}.txt && \
  cat /tmp/sqli_filter_urls_${TMP_FILE}.txt |\
  grep = > /tmp/sqli_parameter_urls_${TMP_FILE}.txt && \
  cat /tmp/sqli_parameter_urls_${TMP_FILE}.txt | grep "$1" | sort | uniq |\
  sqlmap -v 0 -m -
}
```

### 2. **XSS Testing Pipeline**
**Similar pattern for XSS detection**

### 3. **Comprehensive Recon**
**Technique**: Structured output directory
```bash
a.bust() {
  TARGET=`echo $1 | choose -f '//' 1`
  NOW=`date "+%Y%m%d_%H%M%S"`
  ASSESSMENT_NAME=${NOW}_${TARGET}
  
  mkdir $HOME/scans/$ASSESSMENT_NAME
  echo file://$HOME/scans/$ASSESSMENT_NAME
  # All scan outputs go to organized directory
}
```

### 4. **AWS Key Enumeration**
**Technique**: Quick IAM permission check
```bash
a.iam() {
  docker run --rm redgo python3 enumerate-iam/enumerate-iam.py \
    --access-key $1 --secret-key $2
}
```

## Resource Management

### 1. **Docker Image Management**
**Technique**: Categorized pull functions
```bash
function pull_tools_docker() {
  # Security tools
  docker pull aquasec/trivy
  docker pull projectdiscovery/nuclei
  # ... organized by category
}

function pull_vulnerable_things_docker() {
  # Vulnerable apps for testing
  docker pull bkimminich/juice-shop
  docker pull citizenstig/dvwa
  # ... training environments
}
```

### 2. **Conditional Resource Loading**
**Technique**: Check for API keys before pulling resources
```bash
if [[ "$?" == "0" && -f "/etc/api-huggingface" ]]; then
  export HUGGINGFACE_TOKEN=`cat /etc/api-huggingface`
  docker-build/run.sh
fi
```

## Monitoring & Alerting

### 1. **Desktop Notifications with Actions**
**Technique**: Interactive notifications
```bash
dunst-handle() {
  if [[ "$#" -eq "2" ]]; then
    ACTION=$(dunstify --action="default,Open" "$1")
    case "$ACTION" in
    "default")
      firefox "$2"
      ;;
    esac
  else
    dunstify "$1"
  fi
}
```

### 2. **Scheduled Alarms**
**Technique**: Simple reminder system
```bash
a.alarm() {
  echo "/etc/profiles/per-user/user/bin/twmnc -c \"### $2 ###\"" | at $1
}
```

## Data Protection

### 1. **Screen Session Management**
**Technique**: Background processes with easy management
```bash
TIMESTAMP=`date +%Y%m%d_%H%M%S`
screen -S ${TIMESTAMP}_taskname -adm command
# Later: screen -S ${TIMESTAMP}_taskname -X quit
```

### 2. **Volume-based Data Persistence**
**Pattern**: Named volumes for tool data
```bash
docker run -v ${CLIENT_NAME}-tool-data:/data tool:latest
```

### 3. **Password Generation and Display**
**Technique**: QR codes for easy password sharing
```bash
PASSWORD_CLEAR=`pwgen 10`
echo -n "$PASSWORD_CLEAR" | qrencode -t UTF8
```

## Implementation Recommendations

### High Priority Implementations

1. **SSH Login Monitoring**
2. **Docker Security Checks**
3. **Temporary File Management with UUIDs**
4. **Background Task Notifications**
5. **Structured Scan Output Directories**

### Medium Priority

1. **Localhost.run Integration**
2. **Docker Volume Caching**
3. **Parallel Execution Patterns**
4. **Interactive Notifications**

### Nice to Have

1. **QR Code Password Sharing**
2. **Browser Proxy Shortcuts**
3. **Alarm System Integration**

These techniques demonstrate sophisticated approaches to security automation, testing, and operations management. They emphasize efficiency, security, and user experience in daily security operations.