#!/usr/bin/bash

set -euo pipefail

# These files are created during package installation, but /var is persistent
# across bootc updates. Recreate static defaults at first boot instead of
# baking generated state into the image.
rm -rf /var/lib/dnf/repos

install -d /usr/lib/alternatives /usr/lib/netbird /usr/lib/tmpfiles.d
seed_config=/usr/lib/tmpfiles.d/95-cloud-ublue-seeds.conf
touch "$seed_config"

shopt -s nullglob
for source in /var/lib/alternatives/*; do
    [[ -f $source ]] || continue

    name=${source##*/}
    read -r mode owner group < <(stat -c '%a %U %G' "$source")
    install -m "$mode" -o "$owner" -g "$group" "$source" "/usr/lib/alternatives/$name"
    printf 'C /var/lib/alternatives/%s %s %s %s - /usr/lib/alternatives/%s\n' \
        "$name" "$mode" "$owner" "$group" "$name" >> "$seed_config"
    rm -f "$source"
done

if [[ -f /var/lib/netbird/service.json ]]; then
    read -r mode owner group < <(stat -c '%a %U %G' /var/lib/netbird/service.json)
    install -m "$mode" -o "$owner" -g "$group" \
        /var/lib/netbird/service.json /usr/lib/netbird/service.json
    printf 'C /var/lib/netbird/service.json %s %s %s - /usr/lib/netbird/service.json\n' \
        "$mode" "$owner" "$group" >> "$seed_config"
    rm -f /var/lib/netbird/service.json
fi

if [[ -f /var/lib/authselect/checksum ]]; then
    install -d /usr/lib/authselect
    read -r mode owner group < <(stat -c '%a %U %G' /var/lib/authselect/checksum)
    install -m "$mode" -o "$owner" -g "$group" \
        /var/lib/authselect/checksum /usr/lib/authselect/checksum
    printf 'C /var/lib/authselect/checksum %s %s %s - /usr/lib/authselect/checksum\n' \
        "$mode" "$owner" "$group" >> "$seed_config"
    rm -f /var/lib/authselect/checksum
fi
rm -f /var/lib/authselect/checksum

# The syslinux modules under /boot are not used by bootc deployments. Keep the
# installed tools and their /usr files, but leave the boot filesystem empty.
rm -rf /boot/extlinux

# Direct DNF installs can create /var directories after rpm-ostree's generated
# tmpfiles rules were assembled. Add missing rules using each directory's
# installed ownership and mode so they are recreated on first boot.
var_dirs_config=/usr/lib/tmpfiles.d/90-cloud-ublue-var-dirs.conf
tmpfiles_config=$(mktemp)
trap 'rm -f "$tmpfiles_config"' EXIT
: > "$var_dirs_config"

for config_dir in /etc/tmpfiles.d /run/tmpfiles.d /usr/local/lib/tmpfiles.d /usr/lib/tmpfiles.d; do
    [[ -d $config_dir ]] || continue
    while IFS= read -r -d '' config; do
        [[ $config == "$var_dirs_config" ]] || cat "$config" >> "$tmpfiles_config"
    done < <(find "$config_dir" -maxdepth 1 -type f -name '*.conf' -print0)
done

mapfile -t configured_paths < <(
    awk 'NF >= 2 && $1 !~ /^#/ { print $2 }' "$tmpfiles_config"
)

while IFS= read -r -d '' directory; do
    covered=false
    for configured_path in "${configured_paths[@]}"; do
        if [[ $directory == "$configured_path" ]]; then
            covered=true
            break
        fi
    done
    [[ $covered == true ]] && continue

    read -r mode owner group < <(stat -c '%a %U %G' "$directory")
    printf 'd %s %s %s %s - -\n' "$directory" "$mode" "$owner" "$group" \
        >> "$var_dirs_config"
done < <(find /var -mindepth 1 -type d -print0)
