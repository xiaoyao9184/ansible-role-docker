#!/bin/bash

script_path=$(dirname "$(realpath "$0")")
script_name=$(basename "$0")
script_name_no_ext="${script_name%.*}"

STDOUT_JSON=false

for arg in "$@"; do
    case "$arg" in
        --stdout)
            STDOUT_JSON=true
            ;;
        *)
            echo "unknow: $arg"
            echo "usage: $0 [--stdout]"
            exit 1
            ;;
    esac
done

json_array=()

os_name=raspbian
paths=()
paths+=("bookworm/raspbian.12/armhf")
paths+=("bullseye/raspbian.11/armhf")
paths+=("buster/raspbian.10/armhf")
paths+=("jessie/raspbian/armhf")
paths+=("stretch/raspbian/armhf")

for path in "${paths[@]}"; do
    IFS='/' read -r os_version os_version2 os_arch <<< "$path"

    while IFS= read -r line; do
        if [[ "$line" =~ ^docker-ce_[0-9]+ ]]; then
            package_version="${line#docker-ce_}"
            package_version="${package_version%.deb}"
            package_version="${package_version%_$os_arch}"
            # package_version="${package_version%~$os_version}"
            # package_version="${package_version%~$os_version2}"

            IFS='-' read -r docker_version p <<< "$package_version"
            IFS='~' read -r docker_version p <<< "$docker_version"
            docker_version="${docker_version%.ce}"

            json_obj="{\"docker_version\": \"$docker_version\", \"package_version\": \"$package_version\", \"os_name\": \"$os_name\", \"os_version\": \"$os_version\", \"os_arch\": \"$os_arch\"}"
            json_array+=("$json_obj")
        fi
    done < <(curl -s https://download.docker.com/linux/$os_name/dists/$os_version/pool/stable/$os_arch/ | grep -oP 'href="\K[^"]+' | sort)
done

if [[ "$STDOUT_JSON" == "true" ]]; then
    printf "[%s]\n" "$(IFS=,; echo "${json_array[*]}")" | jq 'sort_by(.name)'
else
    printf "[%s]\n" "$(IFS=,; echo "${json_array[*]}")" | jq 'sort_by(.name)' > $script_path/$script_name_no_ext.json
fi
