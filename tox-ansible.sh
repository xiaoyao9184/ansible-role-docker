#!/bin/bash

STDOUT_JSON=false
INCLUDE_CGROUP=auto

for arg in "$@"; do
    case "$arg" in
        --stdout)
            STDOUT_JSON=true
            ;;
        --cgroup=v1)
            INCLUDE_CGROUP=v1
            ;;
        --cgroup=v2)
            INCLUDE_CGROUP=v2
            ;;
        --cgroup=auto)
            INCLUDE_CGROUP=auto
            ;;
        *)
            echo "unknow: $arg"
            echo "usage: $0 [--stdout] [--cgroup=v1|v2|auto]"
            exit 1
            ;;
    esac
done

environment__configs=()

for i in {3..11}; do
    while IFS= read -r line; do
        environment__configs+=("${line} tox-ansible${i}@cgroupv1.ini")
    done < <(tox -c tox-ansible${i}@cgroupv1.ini -l 2>/dev/null)
    while IFS= read -r line; do
        environment__configs+=("${line} tox-ansible${i}@cgroupv2.ini")
    done < <(tox -c tox-ansible${i}@cgroupv2.ini -l 2>/dev/null)
done

enable_environment__configs=()

for environment__conf in "${environment__configs[@]}"; do
    IFS=' ' read -r environment conf <<< "$environment__conf"
    skip=$(grep "skip.environment.$environment" $conf)
    if [[ -n "$skip" ]]; then
        continue
    fi

    IFS='@' read -r py_ansible scenario <<< "$environment"
    if [[ -z "$scenario" ]]; then
        IFS='@' read -r py ansible scenario <<< "$environment"
    else
        IFS='-' read -r py ansible <<< "$py_ansible"
    fi
    skip=$(grep "skip.scenario.$scenario" $conf)
    if [[ -n "$skip" ]]; then
        continue
    fi
    skip=$(grep "skip.py.$py" $conf)
    if [[ -n "$skip" ]]; then
        continue
    fi
    skip=$(grep "skip.ansible.$ansible" $conf)
    if [[ -n "$skip" ]]; then
        continue
    fi
    skip=$(grep "skip.py-ansible.$py-$ansible" $conf)
    if [[ -n "$skip" ]]; then
        continue
    fi

    IFS='-' read -r cgroup target <<< "$scenario"
    skip=$(grep "skip.ansible-target.$ansible-$target" $conf)
    if [[ -n "$skip" ]]; then
        continue
    fi

    enable_environment__configs+=("$environment__conf")
done

json_array=()

for environment__conf in "${enable_environment__configs[@]}"; do
    IFS=' ' read -r environment conf  <<< "$environment__conf"
    IFS='@' read -r py_ansible scenario <<< "$environment"
    if [[ -z "$scenario" ]]; then
        IFS='@' read -r py ansible scenario <<< "$environment"
    else
        IFS='-' read -r py ansible <<< "$py_ansible"
    fi
    IFS='-' read -r cgroup target <<< "$scenario"

    if [[ "$INCLUDE_CGROUP" == "auto" && "$cgroup" == "cgroupv1" && "${enable_environment__configs[*]}" =~ "$py-$ansible-@cgroupv2-$target tox-$ansible@cgroupv2.ini" ]]; then
        # skip if cgroup v2 exists skip cgroupv1
        continue
    elif [[ "$INCLUDE_CGROUP" == "v1" && "$cgroup" == "cgroupv2" ]]; then
        # skip cgroupv2
        continue
    elif [[ "$INCLUDE_CGROUP" == "v2" && "$cgroup" == "cgroupv1" ]]; then
        # skip cgroupv1
        continue
    fi

    # override run_on
    run_on=$(grep "set.cgroup.$cgroup.run_on" $conf | awk -F ' = ' '{print $2}')
    if [[ -z "$run_on" ]]; then
        if [[ "$cgroup" == "cgroupv1" ]]; then
            run_on="ubuntu-20.04"
        else
            run_on="ubuntu-22.04"
        fi
    fi

    python_version=$(echo "$py" | awk '{gsub("py", ""); print substr($0,1,1) "." substr($0,2)}')

    json_obj="{\"name\": \"$target-$ansible(py$python_version)@$cgroup\", \"run_on\": \"$run_on\", \"python_version\": \"$python_version\", \"conf\": \"$conf\", \"environment\": \"$environment\", \"factors\": [\"python$python_version\", \"$ansible\", \"$target\", \"$cgroup\"]}"
    json_array+=("$json_obj")
done

if [[ "$STDOUT_JSON" == "true" ]]; then
    # sort by target and ansible
    printf "[%s]\n" "$(IFS=,; echo "${json_array[*]}")" | jq 'sort_by(.name)'
else
    for json_obj in "${json_array[@]}"; do
        conf=$(echo "$json_obj" | jq -r '.conf')
        env=$(echo "$json_obj" | jq -r '.environment')
        echo tox -c "$conf" -e "$env" -v
    done
fi
