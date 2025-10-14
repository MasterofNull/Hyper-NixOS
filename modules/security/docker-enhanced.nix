{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.security.docker.enhanced;
  
  # Docker safe wrapper script
  dockerSafeScript = pkgs.writeScriptBin "docker-safe" ''
    #!${pkgs.bash}/bin/bash
    # Docker wrapper with security checks
    
    # Forbidden directories for volume mounts
    FORBIDDEN_DIRS=(${concatStringsSep " " (map (d: ''"${d}"'') cfg.volumeRestrictions)})
    
    # Check if running with volume mount
    if echo "$@" | ${pkgs.gnugrep}/bin/grep -qE -- '-v|--volume'; then
        # Extract volume mount paths
        VOLUME_ARGS=$(echo "$@" | ${pkgs.gnugrep}/bin/grep -oE -- '-v [^ ]+|--volume [^ ]+' | ${pkgs.gnused}/bin/sed 's/-v //g; s/--volume //g')
        
        while IFS= read -r volume; do
            # Extract host path (before colon)
            HOST_PATH=$(echo "$volume" | ${pkgs.coreutils}/bin/cut -d: -f1)
            
            # Resolve to absolute path
            if [[ "$HOST_PATH" =~ ^\. ]]; then
                HOST_PATH=$(${pkgs.coreutils}/bin/realpath "$HOST_PATH")
            fi
            
            # Check against forbidden directories
            for forbidden in "''${FORBIDDEN_DIRS[@]}"; do
                if [[ "$HOST_PATH" == "$forbidden" ]] || [[ "$HOST_PATH" == "$forbidden"/* ]]; then
                    echo -e "\033[0;31mERROR: Cannot mount $HOST_PATH - security policy violation\033[0m"
                    echo "Forbidden directories: ''${FORBIDDEN_DIRS[*]}"
                    exit 1
                fi
            done
        done <<< "$VOLUME_ARGS"
    fi
    
    # Execute docker command
    exec ${pkgs.docker}/bin/docker "$@"
  '';
  
  # Docker volume cache helper
  dockerCacheScript = pkgs.writeScriptBin "docker-cache" ''
    #!${pkgs.bash}/bin/bash
    # Docker volume caching helper
    
    VOLUME_NAME=$1
    GENERATE_CMD=$2
    SERVE_CMD=$3
    
    if [[ -z "$VOLUME_NAME" ]] || [[ -z "$GENERATE_CMD" ]] || [[ -z "$SERVE_CMD" ]]; then
        echo "Usage: docker-cache <volume-name> <generate-command> <serve-command>"
        exit 1
    fi
    
    # Check if volume exists
    if ${pkgs.docker}/bin/docker volume inspect "$VOLUME_NAME" &>/dev/null; then
        echo -e "\033[1;33mVolume $VOLUME_NAME exists.\033[0m"
        ${pkgs.coreutils}/bin/echo -n "Use existing data? [Y/n] "
        read -r response
        
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            eval "$SERVE_CMD"
            exit 0
        fi
        
        # Remove existing volume
        ${pkgs.docker}/bin/docker volume rm "$VOLUME_NAME"
    fi
    
    echo -e "\033[1;33mGenerating new data...\033[0m"
    eval "$GENERATE_CMD"
    
    echo -e "\033[1;33mServing...\033[0m"
    eval "$SERVE_CMD"
  '';
  
  # Docker cleanup script
  dockerCleanScript = pkgs.writeScriptBin "docker-clean" ''
    #!${pkgs.bash}/bin/bash
    # Clean docker containers by pattern
    
    PATTERN=$1
    if [[ -z "$PATTERN" ]]; then
        echo "Usage: docker-clean <name-pattern>"
        echo "Example: docker-clean 'test-*'"
        exit 1
    fi
    
    CONTAINERS=$(${pkgs.docker}/bin/docker ps -a -q -f "name=$PATTERN")
    if [[ -n "$CONTAINERS" ]]; then
        echo -e "\033[1;33mStopping and removing containers matching '$PATTERN'\033[0m"
        ${pkgs.docker}/bin/docker stop $CONTAINERS
        ${pkgs.docker}/bin/docker rm $CONTAINERS
        echo -e "\033[0;32mCleaned up containers\033[0m"
    else
        echo "No containers found matching '$PATTERN'"
    fi
  '';
in
{
  options.security.docker.enhanced = {
    enable = mkEnableOption "enhanced Docker security features";
    
    volumeRestrictions = mkOption {
      type = types.listOf types.str;
      default = [ "/" "/etc" "/root" "/home" "~/.ssh" "~/.aws" "~/.gnupg" ];
      description = "Directories forbidden for Docker volume mounts";
    };
    
    enableCaching = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Docker volume caching helpers";
    };
    
    resourceLimits = {
      memory = mkOption {
        type = types.str;
        default = "2g";
        description = "Default memory limit for containers";
      };
      
      cpus = mkOption {
        type = types.str;
        default = "1.5";
        description = "Default CPU limit for containers";
      };
    };
    
    securityScanning = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic security scanning of images";
    };
  };
  
  config = mkIf cfg.enable {
    # Install Docker and security tools
    virtualisation.docker = {
      enable = true;
      
      # Docker daemon settings
      daemon.settings = {
        # Resource limits
        "default-ulimits" = {
          "nofile" = {
            "Name" = "nofile";
            "Hard" = 64000;
            "Soft" = 64000;
          };
        };
        
        # Logging
        "log-driver" = "json-file";
        "log-opts" = {
          "max-size" = "10m";
          "max-file" = "3";
          "labels" = "lifecycle";
        };
        
        # Security options
        "icc" = false;  # Disable inter-container communication
        "live-restore" = true;
        "userland-proxy" = false;
        "no-new-privileges" = true;
        
        # Default security options for containers
        "default-runtime" = "runc";
        "seccomp-profile" = "/etc/docker/seccomp.json";
      };
    };
    
    # Security scripts
    environment.systemPackages = with pkgs; [
      dockerSafeScript
      docker-compose
    ] ++ optionals cfg.enableCaching [
      dockerCacheScript
      dockerCleanScript
    ] ++ optional cfg.securityScanning (
      writeScriptBin "docker-scan" ''
        #!${bash}/bin/bash
        # Scan Docker images for vulnerabilities
        
        IMAGE=''${1:-$(${docker}/bin/docker ps --format "{{.Image}}" | head -1)}
        
        if [[ -z "$IMAGE" ]]; then
            echo "Usage: docker-scan <image>"
            echo "Or run with a container running"
            exit 1
        fi
        
        echo -e "\033[1;33mScanning $IMAGE for vulnerabilities...\033[0m"
        
        ${docker}/bin/docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            --severity HIGH,CRITICAL \
            "$IMAGE"
      ''
    );
    
    # Seccomp profile
    environment.etc."docker/seccomp.json".text = builtins.toJSON {
      defaultAction = "SCMP_ACT_ERRNO";
      architectures = [ "SCMP_ARCH_X86_64" "SCMP_ARCH_X86" "SCMP_ARCH_X32" ];
      syscalls = [
        {
          names = [
            "accept" "accept4" "access" "alarm" "bind" "brk" "capget" "capset"
            "chdir" "chmod" "chown" "chown32" "clock_getres" "clock_gettime"
            "clock_nanosleep" "close" "connect" "copy_file_range" "creat"
            "dup" "dup2" "dup3" "epoll_create" "epoll_create1" "epoll_ctl"
            "epoll_ctl_old" "epoll_pwait" "epoll_wait" "epoll_wait_old"
            "eventfd" "eventfd2" "execve" "execveat" "exit" "exit_group"
            "faccessat" "fadvise64" "fadvise64_64" "fallocate" "fanotify_mark"
            "fchdir" "fchmod" "fchmodat" "fchown" "fchown32" "fchownat"
            "fcntl" "fcntl64" "fdatasync" "fgetxattr" "flistxattr" "flock"
            "fork" "fremovexattr" "fsetxattr" "fstat" "fstat64" "fstatat64"
            "fstatfs" "fstatfs64" "fsync" "ftruncate" "ftruncate64" "futex"
            "futimesat" "getcpu" "getcwd" "getdents" "getdents64" "getegid"
            "getegid32" "geteuid" "geteuid32" "getgid" "getgid32" "getgroups"
            "getgroups32" "getitimer" "getpeername" "getpgid" "getpgrp"
            "getpid" "getppid" "getpriority" "getrandom" "getresgid"
            "getresgid32" "getresuid" "getresuid32" "getrlimit" "get_robust_list"
            "getrusage" "getsid" "getsockname" "getsockopt" "get_thread_area"
            "gettid" "gettimeofday" "getuid" "getuid32" "getxattr" "inotify_add_watch"
            "inotify_init" "inotify_init1" "inotify_rm_watch" "io_cancel"
            "ioctl" "io_destroy" "io_getevents" "ioprio_get" "ioprio_set"
            "io_setup" "io_submit" "ipc" "kill" "lchown" "lchown32" "lgetxattr"
            "link" "linkat" "listen" "listxattr" "llistxattr" "_llseek"
            "lremovexattr" "lseek" "lsetxattr" "lstat" "lstat64" "madvise"
            "memfd_create" "mincore" "mkdir" "mkdirat" "mknod" "mknodat"
            "mlock" "mlock2" "mlockall" "mmap" "mmap2" "mprotect" "mq_getsetattr"
            "mq_notify" "mq_open" "mq_timedreceive" "mq_timedsend" "mq_unlink"
            "mremap" "msgctl" "msgget" "msgrcv" "msgsnd" "msync" "munlock"
            "munlockall" "munmap" "nanosleep" "newfstatat" "_newselect"
            "open" "openat" "pause" "pipe" "pipe2" "poll" "ppoll" "prctl"
            "pread64" "preadv" "prlimit64" "pselect6" "pwrite64" "pwritev"
            "read" "readahead" "readlink" "readlinkat" "readv" "recv"
            "recvfrom" "recvmmsg" "recvmsg" "remap_file_pages" "removexattr"
            "rename" "renameat" "renameat2" "restart_syscall" "rmdir"
            "rt_sigaction" "rt_sigpending" "rt_sigprocmask" "rt_sigqueueinfo"
            "rt_sigreturn" "rt_sigsuspend" "rt_sigtimedwait" "rt_tgsigqueueinfo"
            "sched_getaffinity" "sched_getattr" "sched_getparam" "sched_get_priority_max"
            "sched_get_priority_min" "sched_getscheduler" "sched_rr_get_interval"
            "sched_setaffinity" "sched_setattr" "sched_setparam" "sched_setscheduler"
            "sched_yield" "seccomp" "select" "semctl" "semget" "semop"
            "semtimedop" "send" "sendfile" "sendfile64" "sendmmsg" "sendmsg"
            "sendto" "setdomainname" "setfsgid" "setfsgid32" "setfsuid"
            "setfsuid32" "setgid" "setgid32" "setgroups" "setgroups32"
            "sethostname" "setitimer" "setpgid" "setpriority" "setregid"
            "setregid32" "setresgid" "setresgid32" "setresuid" "setresuid32"
            "setreuid" "setreuid32" "setrlimit" "set_robust_list" "setsid"
            "setsockopt" "set_thread_area" "set_tid_address" "setuid"
            "setuid32" "setxattr" "shmat" "shmctl" "shmdt" "shmget"
            "shutdown" "sigaltstack" "signalfd" "signalfd4" "sigreturn"
            "socket" "socketcall" "socketpair" "splice" "stat" "stat64"
            "statfs" "statfs64" "statx" "symlink" "symlinkat" "sync"
            "sync_file_range" "syncfs" "sysinfo" "syslog" "tee" "tgkill"
            "time" "timer_create" "timer_delete" "timerfd_create" "timerfd_gettime"
            "timerfd_settime" "timer_getoverrun" "timer_gettime" "timer_settime"
            "times" "tkill" "truncate" "truncate64" "ugetrlimit" "umask"
            "uname" "unlink" "unlinkat" "utime" "utimensat" "utimes"
            "vfork" "vmsplice" "wait4" "waitid" "waitpid" "write" "writev"
          ];
          action = "SCMP_ACT_ALLOW";
        }
      ];
    };
    
    # Systemd service for periodic image scanning
    systemd.services.docker-security-scan = mkIf cfg.securityScanning {
      description = "Docker security scanning service";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "docker-scan-all" ''
          #!${pkgs.bash}/bin/bash
          
          echo "Scanning all Docker images for vulnerabilities..."
          
          IMAGES=$(${pkgs.docker}/bin/docker images --format "{{.Repository}}:{{.Tag}}" | ${pkgs.gnugrep}/bin/grep -v "<none>")
          
          for image in $IMAGES; do
              echo "Scanning $image..."
              ${pkgs.docker}/bin/docker run --rm \
                  -v /var/run/docker.sock:/var/run/docker.sock \
                  aquasec/trivy:latest image \
                  --severity HIGH,CRITICAL \
                  --quiet \
                  "$image" || true
          done
        '';
      };
    };
    
    systemd.timers.docker-security-scan = mkIf cfg.securityScanning {
      description = "Docker security scanning timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}