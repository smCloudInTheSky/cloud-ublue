export repo_organization := lowercase(env("GITHUB_REPOSITORY_OWNER", "smcloudinthesky"))
rechunker_image := "ghcr.io/ublue-os/legacy-rechunk:v1.0.1@sha256:2627cbf92ca60ab7372070dcf93b40f457926f301509ffba47a04d6a9e1ddaf7"
export default_image := env("IMAGE_NAME", "cloud-ublue")
export default_tag := env("DEFAULT_TAG", "latest")
export default_flavor := env("DEFAULT_FLAVOR","main")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")
export SUDOIF := if `id -u` == "0" { "" } else { "sudo" }
export PODMAN := if path_exists("/usr/bin/podman") == "true" { env("PODMAN", "/usr/bin/podman") } else if path_exists("/usr/bin/docker") == "true" { env("PODMAN", "docker") } else { env("PODMAN", "exit 1 ; ") }
export PULL_POLICY := if PODMAN =~ "docker" { "missing" } else { "newer" }
chunkah := shell("yq -r \".images[] | select(.name == \\\"chunkah\\\") | \\\"\\\\(.image):\\(.tag)@\\\\(.digest)\\\"\" image-versions.yml")


just := just_executable()
images := '(
    [cloud-ublue]=cloud-ublue
    [thinkpad-ublue]=thinkpad-ublue
)'
flavors := '(
    [main]=main
)'
tags := '(
    [stable]=stable
    [latest]=latest
    [beta]=beta
)'
alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    rm -rf /run/user/1000/containers/ /run/user/1000/libpod/tmp
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# This Justfile recipe builds a container image using Podman.
#
# Arguments:
#   $target_image - The tag you want to apply to the image (default: $image_name).
#   $tag - The tag for the image (default: $default_tag).
#
# The script constructs the version string using the tag and the current date.
# If the git working directory is clean, it also includes the short SHA of the current HEAD.
#
# just build $target_image $tag
#
# Example usage:
#   just build aurora lts
#
# This will build an image 'aurora:lts' with DX and GDX enabled.
#

# Build the image using the specified parameters
build $target_image=default_image $tag=default_tag:
    #!/usr/bin/env bash

    BUILD_ARGS=()
    BUILD_TARGET=cloud-ublue
    if [[ "${target_image##*/}" == "thinkpad-ublue" ]]; then
        BUILD_TARGET=thinkpad-ublue
    fi

    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    podman build \
        "${BUILD_ARGS[@]}" \
        --target "${BUILD_TARGET}" \
        --pull=newer \
        --tag "${target_image}:${tag}" \
        .

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled. Default is 'default_tag'.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.

_rootful_load_image $target_image=default_image $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Command: _check_image_system_files
# Description: Fails early when the image about to be converted into a disk does
#              not contain the configuration baked in from system_files/. The
#              expected entries are read from the system_files/ layout itself
#              (directories, files and symlinks), so this check stays in sync
#              when the overlay changes. This catches stale images when
#              `just build-qcow2` is run without first rebuilding the image.
#
# Parameters:
#   $target_image - The image that bootc-image-builder will convert.
#   $tag - The tag of the target image.

[private]
_check_image_system_files $target_image $tag:
    #!/usr/bin/env bash
    set -euo pipefail

    # Nothing to enforce when the repo has no system_files/ overlay.
    if [[ ! -d system_files ]]; then
        exit 0
    fi

    # Remote images are converted as-is; only guard images built from this repo.
    case "${target_image}" in
        localhost/*|"${default_image}") ;;
        *)
            echo "Skipping system_files check for remote image ${target_image}:${tag}."
            exit 0
            ;;
    esac

    if ! sudo podman image exists "${target_image}:${tag}"; then
        echo "Image ${target_image}:${tag} was not found in rootful podman storage." >&2
        exit 1
    fi

    echo "Converting image: $(sudo podman image inspect "${target_image}:${tag}" | jq -r '.[0].Id + " (created " + .[0].Created + ")"')"

    # Build the check script from the overlay layout so it cannot drift from
    # system_files/. It runs inside the image with /bin/sh.
    check_script="missing=0"
    while IFS= read -r -d '' record; do
        kind=${record:0:1}
        rel=${record:2}
        dest="/${rel}"
        printf -v quoted '%q' "${dest}"
        case "${kind}" in
            d) test_flag="-d" ;;
            f) test_flag="-f" ;;
            l) test_flag="-L" ;;
            *) continue ;;
        esac
        check_script+="; if [ ${test_flag} ${quoted} ]; then echo \"  OK   ${dest}\"; else echo \"  MISS ${dest}\"; missing=1; fi"
    done < <(find system_files -mindepth 1 -printf '%y %P\0' | sort -z -k2)
    check_script+='; exit "$missing"'

    set +e
    sudo podman run \
        --rm \
        --pull=never \
        --network=none \
        --entrypoint /bin/sh \
        "${target_image}:${tag}" \
        -c "${check_script}"
    rc=$?
    set -e

    if [[ ${rc} -eq 1 ]]; then
        printf '\nImage %s:%s is missing entries from system_files/.\nRefusing to build a disk from a stale image. Rebuild the image first:\n\n    just rebuild-qcow2 %s %s\n\nor:\n\n    just build && just build-qcow2 %s %s\n\n' \
            "${target_image}" "${tag}" "${target_image}" "${tag}" "${target_image}" "${tag}" >&2
        exit 1
    elif [[ ${rc} -ne 0 ]]; then
        echo "Failed to inspect image ${target_image}:${tag} (podman exit ${rc})." >&2
        exit "${rc}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
# Converts a container image to a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (default: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag) (_check_image_system_files target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Podman builds the image from the Containerfile and creates a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (deafult: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Build a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
build-qcow2 $target_image=("localhost/" + default_image) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml") (verify-qcow2 "output/qcow2/disk.qcow2")

# Build a RAW virtual machine image
[group('Build Virtal Machine Image')]
build-raw $target_image=("localhost/" + default_image) $tag=default_tag: && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Build an ISO virtual machine image
[group('Build Virtal Machine Image')]
build-iso-gnome $target_image=("localhost/" + default_image) $tag=default_tag: && (_build-bib target_image tag "iso" "disk_config/iso-gnome.toml")

# Rebuild a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + default_image) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml") (verify-qcow2 "output/qcow2/disk.qcow2")

# Verify a built disk matches the layout under system_files/.
# Walks every entry in the overlay (directories, regular files, symlinks),
# resolves the bootc deployment inside the disk with libguestfs and checks that
# the deployed copy exists at the same relative path and has the same content.
# No VM boot is required. Skips with a warning when libguestfs is not installed.
#
# A deployed file may be larger than its source when a build script appends to
# it (for example build_thinkpad.sh appends to system-flatpaks.list); that case
# passes when the source is a byte-prefix of the deployed file.
# Parameters:
# $disk - The disk image to inspect (default: output/qcow2/disk.qcow2).
# $overlay - The overlay directory to compare against (default: system_files).
[group('Build Virtal Machine Image')]
verify-qcow2 $disk="output/qcow2/disk.qcow2" $overlay="system_files":
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v guestfish >/dev/null || ! command -v virt-filesystems >/dev/null; then
        echo "Skipping disk verification: libguestfs tools (guestfish, virt-filesystems) are not installed." >&2
        exit 0
    fi

    if [[ ! -f ${disk} ]]; then
        echo "Disk image not found: ${disk}" >&2
        exit 1
    fi

    if [[ ! -d ${overlay} ]]; then
        echo "Overlay directory not found: ${overlay}" >&2
        exit 1
    fi

    # Enumerate the overlay: every entry is checked, not a hardcoded list.
    declare -a kinds=() rels=()
    while IFS= read -r -d '' record; do
        kinds+=("${record:0:1}")
        rels+=("${record:2}")
    done < <(find "${overlay}" -mindepth 1 -printf '%y %P\0' | sort -z -k2)

    if [[ ${#rels[@]} -eq 0 ]]; then
        echo "No entries found under ${overlay}/; nothing to verify."
        exit 0
    fi

    rootvol=$(virt-filesystems -a "${disk}" --all --long | awk '$1 ~ /^btrfsvol:/ && $2 == "filesystem" { print $1; exit }')
    if [[ -z ${rootvol} ]]; then
        echo "Could not find a btrfs root subvolume in ${disk}" >&2
        exit 1
    fi

    device=${rootvol#btrfsvol:}
    subvol=${device##*/}
    device=${device%/*}
    mount_spec="${device}:/:subvol=${subvol}"

    deployment=$(guestfish --ro -a "${disk}" -m "${mount_spec}" ls /ostree/deploy/default/deploy | grep -E '^[0-9a-f]+\.0$' | sort | tail -1)
    if [[ -z ${deployment} ]]; then
        echo "Could not find a bootc deployment in ${disk}" >&2
        exit 1
    fi

    root="/ostree/deploy/default/deploy/${deployment}"
    echo "Inspecting ${disk} (deployment ${deployment})"
    echo "Comparing against ${overlay}/ (${#rels[@]} entries)"

    guest_quote() {
        local escaped=${1//\\/\\\\}
        escaped=${escaped//\"/\\\"}
        printf '"%s"' "${escaped}"
    }

    tmpdir=$(mktemp -d)
    trap 'rm -rf "${tmpdir}"' EXIT

    type_cmds="${tmpdir}/types"
    : > "${type_cmds}"

    # Ask guestfish for the type of every entry in one session.
    for i in "${!rels[@]}"; do
        guest_path="${root}/${rels[$i]}"
        case "${kinds[$i]}" in
            d) printf 'is-dir %s\n' "$(guest_quote "${guest_path}")" >> "${type_cmds}" ;;
            f) printf 'is-file %s\n' "$(guest_quote "${guest_path}")" >> "${type_cmds}" ;;
            l) printf 'is-symlink %s\n' "$(guest_quote "${guest_path}")" >> "${type_cmds}" ;;
            *) printf 'echo unsupported-%s\n' "${kinds[$i]}" >> "${type_cmds}" ;;
        esac
    done

    if ! type_output=$(guestfish --ro -a "${disk}" -m "${mount_spec}" -f "${type_cmds}"); then
        echo "Failed to inspect ${disk} with guestfish." >&2
        exit 1
    fi
    mapfile -t type_lines <<< "${type_output}"

    if [[ ${#type_lines[@]} -ne ${#rels[@]} ]]; then
        echo "Unexpected guestfish output while inspecting ${disk}; aborting." >&2
        exit 1
    fi

    declare -A file_targets=()
    declare -a link_indexes=()
    download_cmds="${tmpdir}/downloads"
    readlink_cmds="${tmpdir}/readlinks"
    : > "${download_cmds}"
    : > "${readlink_cmds}"

    failed=0
    for i in "${!rels[@]}"; do
        rel=${rels[$i]}
        kind=${kinds[$i]}
        actual=${type_lines[$i]}

        case "${kind}" in
            d)
                if [[ ${actual} == true ]]; then
                    echo "  OK   /${rel} (directory)"
                else
                    echo "  MISS /${rel} (expected a directory)"
                    failed=1
                fi
                ;;
            f)
                if [[ ${actual} == true ]]; then
                    target="${tmpdir}/file-${i}"
                    file_targets[$i]="${target}"
                    printf 'download %s %s\n' "$(guest_quote "${root}/${rel}")" "$(guest_quote "${target}")" >> "${download_cmds}"
                else
                    echo "  MISS /${rel} (expected a regular file)"
                    failed=1
                fi
                ;;
            l)
                if [[ ${actual} == true ]]; then
                    link_indexes+=("${i}")
                    printf 'readlink %s\n' "$(guest_quote "${root}/${rel}")" >> "${readlink_cmds}"
                else
                    echo "  MISS /${rel} (expected a symlink)"
                    failed=1
                fi
                ;;
            *)
                echo "  SKIP /${rel} (unsupported entry type '${kind}')"
                ;;
        esac
    done

    # Download existing regular files in one session and compare contents.
    if [[ ${#file_targets[@]} -gt 0 ]]; then
        if ! guestfish --ro -a "${disk}" -m "${mount_spec}" -f "${download_cmds}" >/dev/null; then
            echo "Failed to download files from ${disk}." >&2
            exit 1
        fi
    fi

    for i in "${!rels[@]}"; do
        if [[ ! -v file_targets[$i] ]]; then
            continue
        fi

        rel=${rels[$i]}
        source="${overlay}/${rel}"
        deployed=${file_targets[$i]}
        source_size=$(stat -c %s "${source}")
        deployed_size=$(stat -c %s "${deployed}")

        if cmp -s "${source}" "${deployed}"; then
            echo "  OK   /${rel}"
        elif [[ ${deployed_size} -gt ${source_size} ]] && head -c "${source_size}" "${deployed}" | cmp -s "${source}" -; then
            echo "  OK   /${rel} (+$((deployed_size - source_size)) bytes appended during build)"
        else
            echo "  FAIL /${rel} differs from ${overlay}/${rel}"
            failed=1
        fi
    done

    # Read symlink targets in one session and compare them.
    if [[ ${#link_indexes[@]} -gt 0 ]]; then
        if ! link_output=$(guestfish --ro -a "${disk}" -m "${mount_spec}" -f "${readlink_cmds}"); then
            echo "Failed to read symlinks from ${disk}." >&2
            exit 1
        fi
        mapfile -t link_lines <<< "${link_output}"

        for n in "${!link_indexes[@]}"; do
            i=${link_indexes[$n]}
            rel=${rels[$i]}
            expected=$(readlink "${overlay}/${rel}")
            actual=${link_lines[$n]:-}

            if [[ ${actual} == "${expected}" ]]; then
                echo "  OK   /${rel} -> ${actual} (symlink)"
            else
                echo "  FAIL /${rel} -> '${actual}' (expected '${expected}')"
                failed=1
            fi
        done
    fi

    if [[ ${failed} -ne 0 ]]; then
        echo "Disk verification FAILED: ${disk} does not match ${overlay}/. It was probably built from a stale image; run 'just rebuild-qcow2'." >&2
        exit 1
    fi

    echo "Disk verification passed: ${disk} matches ${overlay}/ (${#rels[@]} entries checked)."

# Rebuild a RAW virtual machine image
[group('Build Virtal Machine Image')]
rebuild-raw $target_image=("localhost/" + default_image) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild an ISO virtual machine image
[group('Build Virtal Machine Image')]
rebuild-iso-gnome $target_image=("localhost/" + default_image) $tag=default_tag: && (_rebuild-bib target_image tag "iso" "disk_config/iso-gnome.toml")

# Check if valid combo
[arg("flavor", long="flavor", short="f")]
[arg("image", long="image", short="i")]
[arg("tag", long="tag", short="t")]
[private]
validate $image $tag $flavor:
    #!/usr/bin/env bash
    set -eou pipefail

    declare -A images={{ images }}
    declare -A tags={{ tags }}
    declare -A flavors={{ flavors }}

    checkimage="${images[${image}]-}"
    checktag="${tags[${tag}]-}"
    checkflavor="${flavors[${flavor}]-}"

    # Validity Checks
    if [[ -z "$checkimage" ]]; then
        echo "Invalid Image..."
        exit 1
    fi
    if [[ -z "$checktag" ]]; then
        echo "Invalid tag..."
        exit 1
    fi
    if [[ -z "$checkflavor" ]]; then
        echo "Invalid flavor..."
        exit 1
    fi

# Rechunk Image
[arg("flavor", long="flavor", short="f")]
[arg("image", long="image", short="i")]
[arg("tag", long="tag", short="t")]
[group('Image')]
rechunk $image=default_image $tag=default_tag $flavor=default_flavor:
    #!/usr/bin/env bash
    set -eoux pipefail

    {{ just }} validate --image "${image}" --tag "${tag}" --flavor "${flavor}"
    image_name=$({{ just }} image_name --image "${image}" --tag "${tag}" --flavor "${flavor}")
    CHUNKAH_OUTPUT_DIR="$(mktemp -d)"
    CHUNKAH_CONFIG_FILE="$(mktemp)"

    trap 'rm -f "${CHUNKAH_CONFIG_FILE}"; rm -rf "${CHUNKAH_OUTPUT_DIR}"' EXIT
    ${PODMAN} inspect "${image_name}:${tag}" > "${CHUNKAH_CONFIG_FILE}"

    ${PODMAN} run --rm \
    --env RUST_LOG=chunkah=debug \
    --mount=type=image,src="${image_name}:${tag}",target=/chunkah \
    -v "${CHUNKAH_CONFIG_FILE}:/chunkah-config.json:ro,Z" \
    -v "${CHUNKAH_OUTPUT_DIR}:/run/out:Z" \
    "{{ chunkah }}" \
    build \
    -v \
    --compressed \
    --max-layers 256 \
    --prune /sysroot/ \
    --label ostree.commit- --label ostree.final-diffid- \
    --config /chunkah-config.json \
    --output oci:/run/out/chunked

    CHUNKED_IMAGE="$(${PODMAN} pull "oci:${CHUNKAH_OUTPUT_DIR}/chunked")"
    ${PODMAN} tag "${CHUNKED_IMAGE}" "${image_name}:${tag}"

# Diagnose the rechunk `rpm` failure ("rpm command killed by signal 13").
#
# chunkah loads the rpmdb by running the host `rpm -qa --queryformat ...` and
# piping stdout into a parser. If that parser bails early it closes the pipe,
# which sends SIGPIPE (signal 13) to `rpm`; the *real* error is then masked by
# the "signal 13" message.
#
# Rechunk Image (diagnostic): reveal the real error behind the rpm failure.
[arg("flavor", long="flavor", short="f")]
[arg("image", long="image", short="i")]
[arg("tag", long="tag", short="t")]
[group('Image')]
rechunk-debug $image=default_image $tag=default_tag $flavor=default_flavor:
    #!/usr/bin/env bash
    set -eoux pipefail

    {{ just }} validate --image "${image}" --tag "${tag}" --flavor "${flavor}"
    image_name=$({{ just }} image_name --image "${image}" --tag "${tag}" --flavor "${flavor}")

    DEBUG_DIR="$(mktemp -d)"
    trap 'rm -rf "${DEBUG_DIR}"' EXIT

    ${PODMAN} run --rm \
        --mount=type=image,src="${image_name}:${tag}",target=/chunkah \
        -v "${DEBUG_DIR}:/run/out:Z" \
        -v "$(pwd)/build_files/rechunk-debug.sh:/run/debug.sh:ro,Z" \
        --entrypoint /bin/bash \
        "{{ chunkah }}" /run/debug.sh

    echo "================ rpm stderr (basic) ================"
    cat "${DEBUG_DIR}/basic.err" || true
    echo "================ rpm stderr (full queryformat) ================"
    cat "${DEBUG_DIR}/full.err" || true

    echo "================ structural check of queryformat output ================"
    awk -F'\t' '
        /^@@PKG@@/  { if (NF != 12) print "BAD PKG  line " NR ": " NF " fields"; next }
        /^@@FILE@@/ { if (NF != 10) print "BAD FILE line " NR ": " NF " fields"; next }
        /^@@CL@@/   { if (NF != 2)  print "BAD CL   line " NR ": " NF " fields"; next }
        /^$/        { next }
        { print "UNEXPECTED line " NR ": " substr($0, 1, 80) }
    ' "${DEBUG_DIR}/queryformat.txt" | head -50
    echo "(no output above = output is structurally well-formed)"

# Load OCI into Podman Store
[group('Image')]
load-rechunk image="cloud-ublue" tag="latest" flavor="main":
    #!/usr/bin/bash
    set -eou pipefail

    # Validate
    {{ just }} validate {{ image }} {{ tag }} {{ flavor }}

    # Image Name
    image_name=$({{ just }} image_name {{ image }} {{ tag }} {{ flavor }})

    # Load Image
    OUT_NAME="${image_name}_build"
    IMAGE=$(${PODMAN} pull oci:"${PWD}"/"${OUT_NAME}")
    ${PODMAN} tag ${IMAGE} localhost/"${image_name}":{{ tag }}

    # Cleanup
    rm -rf "${OUT_NAME}*"
    rm -f previous.manifest.json

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtal Machine')]
run-vm-qcow2 $target_image=("localhost/" + default_image) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw $target_image=("localhost/" + default_image) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso-gnome $target_image=("localhost/" + default_image) $tag=default_tag: && (_run-vm target_image tag "iso" "disk_config/iso-gnome.toml")

# Run a virtual machine using systemd-vmspawn
[group('Run Virtal Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}

# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'

# Image Name
[arg("flavor", long="flavor", short="f")]
[arg("image", long="image", short="i")]
[arg("tag", long="tag", short="t")]
[private]
image_name image=default_image tag=default_tag flavor=default_flavor:
    #!/usr/bin/env bash
    set -eoux pipefail

    {{ just }} validate --image {{ image }} --tag {{ tag }} --flavor {{ flavor }}
    if [[ "{{ flavor }}" =~ main ]]; then
        image_name={{ image }}
    else
        image_name="{{ image }}-{{ flavor }}"
    fi

    echo "${image_name}"
