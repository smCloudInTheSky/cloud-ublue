# AGENTS.md - cloud-ublue Repository Analysis

## Overview

**cloud-ublue** is a custom [bootc](https://github.com/bootc-dev/bootc) container image based on **Universal Blue's Bluefin** (which itself is based on Fedora Atomic). This repository serves as a template for building personalized immutable operating system images using the bootc/Containerfile workflow.

**Repository Owner:** `smcloudinthesky`  
**Base Image:** `ghcr.io/ublue-os/bluefin:stable`  
**Output Images:** `ghcr.io/smcloudinthesky/cloud-ublue` and `ghcr.io/smcloudinthesky/thinkpad-ublue`

---

## Architecture

### Multi-Stage Containerfile Build

The `Containerfile` defines a **multi-stage build** with two output images:

```
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: ctx (scratch)                                          │
│   - Copies build_files/ and flatpak/ into build context         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 2: cloud-ublue (FROM ghcr.io/ublue-os/bluefin:stable)    │
│   - Copies cosign.pub for container signing verification        │
│   - Runs build.sh (main customization script)                   │
│   - Runs bootc container lint                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 3: thinkpad-ublue (FROM cloud-ublue)                      │
│   - Runs build_thinkpad.sh (ThinkPad-specific customizations)   │
│   - Runs bootc container lint                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Build Process (GitHub Actions)

Two workflows automate the build pipeline:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **build.yml** | Push to main, PR to main, weekly schedule (Thu 10:05 UTC), manual dispatch | Builds & pushes OCI images to GHCR, signs with cosign |
| **build-disk.yml** | Manual dispatch, PR changes to disk configs | Builds bootable disk images (qcow2, ISO) via bootc-image-builder |

---

## Key Files

### 1. Containerfile
- **Base:** `ghcr.io/ublue-os/bluefin:stable`
- **Build stages:** `ctx` → `cloud-ublue` → `thinkpad-ublue`
- **Signing:** Copies `cosign.pub` to `/etc/pki/containers/cloud.pub`
- **Build mounts:** Uses bind mounts for cache, tmpfs, and build context
- **Linting:** Runs `bootc container lint` on each stage

### 2. build_files/build.sh (Base Customizations)
Installs and configures:
- **COPR repos:** `ilyaz/LACT` (GPU control), `netbird` (VPN)
- **Packages:** `lact`, `libvirt-devel`, `mangohud`, `pipx`, `keepassxc`, `firefox`, `git-lfs`, `clustershell`, `vmaf` tools, `rasdaemon`
- **Custom RPMs:** `r2modmanPlus`, `Devsy` (installed via direct RPM URLs)
- **Services enabled:** `netbird`, `lactd`, `rasdaemon`
- **System flatpaks:** Copies flatpak lists to `/etc/ublue-os/`
- **/opt handling:** Symlinks `/opt` → `/var/opt` for packages needing writable /opt

### 3. build_files/build_thinkpad.sh (ThinkPad Variant)
Additional ThinkPad-specific customizations:
- **COPR repos:** `abn/throttled` (CPU throttling), `sneexy/python-validity` (fingerprint reader)
- **Removes:** `tuned`, `tuned-ppd`
- **Installs:** `igt-gpu-tools`, `fprintd-clients`, `open-fprintd`, `python3-validity`, `tlp`, `tlp-rdw`, `throttled`, `zcfan`
- **Services enabled:** `tlp`, `zcfan`, `throttled`, `open-fprintd-*`, `python3-validity`
- **Services masked:** `systemd-rfkill.service`, `systemd-rfkill.socket`
- **Flatpak:** Adds `com.github.d4nj1.tlpui` to system flatpak list

### 4. Flatpak Lists

**system-flatpaks.list** (45 entries) - End-user applications:
- Communication: Discord, Riot (Element), Thunderbird
- Media: Clapper, VLC, JDownloader, Pinta, Impression
- System: ExtensionManager, Flatseal, Ignition, Warehouse, MissionCenter, Resources, Refine, SafeEyes
- GNOME Core: Calculator, Calendar, Characters, Connections, Contacts, DejaDup, FileRoller, Firmware, Logs, Loupe, Maps, NautilusPreviewer, Papers, TextEditor, Weather, baobab, clocks, font-viewer
- Themes: adw-gtk3, adw-gtk3-dark
- Runtimes: MangoHud, vkBasalt, OBSVkCapture, OBS plugins, Tuner

**system-flatpaks-dx.list** (3 entries) - Developer tools:
- Embellish, PodmanDesktop, DevToolbox

### 5. Disk Configurations

| Config | Purpose | Key Settings |
|--------|---------|--------------|
| `disk.toml` | Generic VM disk (qcow2/raw) | 20 GiB root, btrfs |
| `iso-gnome.toml` | GNOME ISO installer | Kickstart switches to cloud-ublue, minimal installer modules |
| `iso-kde.toml` | KDE ISO installer | Kickstart switches to cloud-ublue, full installer modules |
| `iso.toml` | Legacy ISO config | 50 GiB root, minimal modules |

### 6. Justfile (Local Development Commands)

**Environment Variables:**
- `image_name`: `cloud-ublue` (default)
- `default_tag`: `latest`
- `bib_image`: `quay.io/centos-bootc/bootc-image-builder:latest`

**Key Commands:**
| Command | Description |
|---------|-------------|
| `just build [image] [tag]` | Build container image locally with podman |
| `just build-qcow2` | Build QCOW2 VM image |
| `just build-raw` | Build RAW VM image |
| `just build-iso-gnome` | Build GNOME ISO installer |
| `just rebuild-qcow2` | Rebuild (build + convert) QCOW2 |
| `just run-vm-qcow2` | Run QCOW2 in QEMU with web VNC |
| `just spawn-vm` | Run VM via systemd-vmspawn |
| `just lint` | Shellcheck all .sh files |
| `just format` | shfmt format all .sh files |
| `just clean` | Remove build artifacts |

### 7. CI/CD Configuration

**GitHub Actions (build.yml):**
- Matrix builds both `cloud-ublue` and `thinkpad-ublue`
- Uses `ublue-os/container-storage-action` with BTRFS + zstd compression
- Metadata via `docker/metadata-action` for ArtifactHub + OCI labels
- Builds via `redhat-actions/buildah-build`
- Pushes to GHCR on main branch (not PRs)
- Signs images with cosign (requires `SIGNING_SECRET` secret)

**GitHub Actions (build-disk.yml):**
- Supports `amd64` and `arm64` platforms
- Builds `qcow2` and `anaconda-iso` disk types
- Uses `osbuild/bootc-image-builder-action`
- Optional S3 upload via rclone (requires S3 secrets)

**Dependabot:** Weekly updates for GitHub Actions

**Renovate:** Best practices config with:
- Auto-merge for `pin`, `pinDigest`, and `digest` updates
- GitHub Actions tracking (12 actions across build.yml & build-disk.yml)
- Docker base image tracking (`bluefin:stable`, `bootc-image-builder:latest`)
- **Custom regex managers** for direct RPM installs:
  - `r2modmanPlus` (ebkr/r2modmanPlus GitHub releases)
  - `Devsy` (devsy-org/devsy GitHub releases — requires pinning from `latest` first)

---

## Security

### Container Signing
- **Cosign keyless signing** via GitHub OIDC
- Private key stored in GitHub Secret `SIGNING_SECRET`
- Public key (`cosign.pub`) baked into image at `/etc/pki/containers/cloud.pub`
- Images signed on push to main branch only

### SBOM/Provenance
- OCI image labels include full provenance (source, revision, build date)
- ArtifactHub metadata embedded for discoverability

---

## Customization Points

To adapt this template for your own image:

1. **Containerfile line 6:** Change `FROM ghcr.io/ublue-os/bluefin:stable` to your desired base
2. **Justfile line 1:** Change `export image_name := "cloud-ublue"` to your image name
3. **build_files/build.sh:** Add your package installations and system customizations
4. **flatpak/*.list:** Modify Flatpak applications to include
5. **disk_config/*.toml:** Adjust disk layouts and installer behavior
6. **artifacthub-repo.yml:** Update `repositoryID` and `owners` for ArtifactHub publishing
7. **GitHub Secrets:** Add `SIGNING_SECRET` (cosign private key), optionally S3 credentials

---

## Usage Workflow

```bash
# 1. Use template on GitHub → create your repo
# 2. Generate cosign keys:
COSIGN_PASSWORD="" cosign generate-key-pair
gh secret set SIGNING_SECRET < cosign.key

# 3. Customize Containerfile FROM, Justfile image_name, build.sh
# 4. Commit & push → GitHub Actions builds & publishes to GHCR
# 5. On target machine:
sudo bootc switch ghcr.io/<your-username>/<your-image-name>

# 6. Optional: Build installable ISO locally
just build-iso-gnome
```

---

## Dependencies

### Runtime (in final image)
- Universal Blue base (Bluefin → Fedora Atomic)
- bootc for transactional updates
- rpm-ostree for package layering
- Flatpak for user applications
- systemd for service management

### Build-time
- podman / buildah
- bootc-image-builder (for disk images)
- cosign (for signing)
- GitHub Actions runners (ubuntu-24.04, ubuntu-24.04-arm)

### COPR Repositories Used
| Repo | Purpose | Used In |
|------|---------|---------|
| `ilyaz/LACT` | GPU control daemon | build.sh |
| `netbird` | VPN mesh networking | build.sh (custom repo) |
| `abn/throttled` | CPU throttling daemon | build_thinkpad.sh |
| `sneexy/python-validity` | Fingerprint reader support | build_thinkpad.sh |

### Direct RPM Installs (Tracked by Renovate)
| Package | Repo | Current Version | Tracking |
|---------|------|-----------------|----------|
| `r2modmanPlus` | ebkr/r2modmanPlus | v3.2.18 |  GitHub releases |
| `Devsy` | devsy-org/devsy | v1.15.0|  GitHub releases |

---

## Output Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| OCI Images | `ghcr.io/smcloudinthesky/cloud-ublue:latest`, `:YYYYMMDD` | Bootc container images |
| OCI Images | `ghcr.io/smcloudinthesky/thinkpad-ublue:latest`, `:YYYYMMDD` | ThinkPad variant |
| QCOW2 | GitHub Artifacts / S3 | VM disk image |
| ISO (Anaconda) | GitHub Artifacts / S3 | Bootable installer |

---

## References

- **Universal Blue Project:** https://universal-blue.org
- **bootc Documentation:** https://github.com/bootc-dev/bootc
- **bootc-image-builder:** https://osbuild.org/docs/bootc/
- **Template Source:** This repo follows the Universal Blue image-template pattern
- **Community Examples:** m2os, bOS, Homer, AmyOS, VeneOS (see README.md)
