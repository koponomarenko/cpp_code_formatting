#!/bin/bash
################################################################################
# This is a gerrit commit received hook.
################################################################################

srv_err="Error occured on the server:"

# Parse script args
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --project)
            project="$2"
            shift # past argument
            shift # past value
            ;;
        --refname)
            refname="$2"
            shift # past argument
            shift # past value
            ;;
        --uploader)
            uploader="$2"
            shift # past argument
            shift # past value
            ;;
        --uploader-username)
            uploader_username="$2"
            shift # past argument
            shift # past value
            ;;
        --oldrev)
            oldrev="$2"
            shift # past argument
            shift # past value
            ;;
        --newrev)
            newrev="$2"
            shift # past argument
            shift # past value
            ;;
        --cmdref)
            cmdref="$2"
            shift # past argument
            shift # past value
            ;;
        *) # unknown option
            shift # past argument
            ;;
    esac
done

check_cpp_code_formatting() {
    # path to the root dir with bare git repos
    local repo_root_dir=""

    # path to the repo with clang-format stuff
    local checker_repo_dir="${repo_root_dir}/<path_to_repo>.git"
    # name of the branch where to look for clang-format stuff
    local checker_repo_branch="<branch_name>"
    local checker_file_src="clang-format/server_side/git-bare-clang-format-checker.sh"

    local checker_name="git-bare-clang-format-checker.sh"
    local checker_dir="/tmp"
    local checker="${checker_dir}/${checker_name}"

    # get the latest version of the script in the branch
    pushd ${checker_repo_dir} >/dev/null
    if [ "$?" -ne "0" ]; then
        echo "$srv_err Can't pushd to ${checker_repo_dir}" >&2
        exit 1
    fi
    local checker_file_out="$(env -u GIT_DIR git show \
        ${checker_repo_branch}:${checker_file_src})"
    if [ "$?" -ne "0" ]; then
        echo "$srv_err 'git show" \
            "${checker_repo_branch}:${checker_file_src}'" \
            "returned with error" >&2
        exit 1
    fi
    if [ -z "${checker_file_out}" ]; then
        echo "$srv_err 'checker_file_out' var is empty" >&2
        exit 1
    fi
    popd >/dev/null

    # create script if there is none, or if it's different
    create_file="0"
    if [ ! -f "${checker}" ]; then
        create_file="1"
    else
        cmp -s ${checker} <(printf "%s" "${checker_file_out}")
        [ "$?" -ne "0" ] && create_file="1"
    fi

    if [ "${create_file}" -ne "0" ]; then
        printf "%s" "${checker_file_out}" >${checker}
        if [ "$?" -ne "0" ]; then
            echo "$srv_err Can't create ${checker}" >&2
            exit 1
        fi
    fi

    /bin/bash ${checker} --git-repo $project --commit $newrev
    if [ "$?" -ne "0" ]; then
        exit 1
    fi
}
check_cpp_code_formatting
