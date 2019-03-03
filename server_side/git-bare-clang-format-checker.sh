#!/bin/bash
################################################################################
# This script checks formatting of all files with certain file extension
# in the commit.
#
# SPECIFICS:
# The whole file is checked.
################################################################################

clang_format_bin="/opt/dev_tools/bin/clang-format"

# path to the root dir with bare git repos
repo_root_dir=""

# path to the repo with clang-format stuff
dot_clang_format_file_src_repo_dir="$repo_root_dir/<path_to_repo>.git"
# name of the branch where to look for clang-format stuff
dot_clang_format_file_src_repo_branch="<branch_name>"
dot_clang_format_file_src="clang-format/dot-clang-format"
dot_clang_format_file_dest="$repo_root_dir/<dest_dir>/.clang-format"


file_extensions="(cpp|h|hpp|c|c\+\+|cc|hh|cxx|hxx|C|H)"

srv_err="Error occured on the server:"

################################################################################
#   Parse script args
################################################################################
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --git-repo)
            git_repo="$2"
            shift # past argument
            shift # past value
            ;;
        --commit)
            commit="$2"
            shift # past argument
            shift # past value
            ;;
        *) # unknown option
            shift # past argument
            ;;
    esac
done

################################################################################
#   Check env
################################################################################
if [ ! -f "${clang_format_bin}" ]; then
    echo "$srv_err clang-format not found!" >&2
    exit 1
fi
clang_format_version="7.0.1"
if ! ${clang_format_bin} -version | grep -q "version ${clang_format_version}"; then
    echo "$srv_err clang-format must be version ${clang_format_version}!" >&2
    echo "$srv_err current version is:" >&2
    ${clang_format_bin} -version >&2
    exit 1
fi

if [ -z "$BASH" ]; then
    echo "$srv_err This shell is not bash shell" >&2
    exit 1
fi
if ! which diff &>/dev/null; then
    echo "$srv_err diff binary is not detected" >&2
    exit 1
fi
if ! which git &>/dev/null; then
    echo "$srv_err git binary is not detected" >&2
    exit 1
fi

# in other case all git commands will be called from this dir.
unset GIT_DIR

################################################################################
#   List of repositories to check with clang-format
################################################################################
if ! cd ${dot_clang_format_file_src_repo_dir}; then
    echo "$srv_err Can't cd into ${dot_clang_format_file_src_repo_dir}" >&2
    exit 1
fi

repos_to_check_cpp_formatting_file="clang-format/server_side/repos-to-check-cpp-formatting"
repos_to_check_cpp_formatting_out="$(git show \
    ${dot_clang_format_file_src_repo_branch}:${repos_to_check_cpp_formatting_file})"
if [ "$?" -ne "0" ]; then
    echo "$srv_err 'git show" \
        "${dot_clang_format_file_src_repo_branch}:${repos_to_check_cpp_formatting_file}'" \
        "returned with error" >&2
    exit 1
fi
if [ -z "${repos_to_check_cpp_formatting_out}" ]; then
    echo "$srv_err 'repos_to_check_cpp_formatting_out' var is empty" >&2
    exit 1
fi

. <(printf "%s" "${repos_to_check_cpp_formatting_out}")

################################################################################
#   Check if this repo is in the list of repositories to check formatting
################################################################################
found="0"
for i in "${projects[@]}"; do
    if [[ "$i" == "$git_repo" ]]; then
        found="1"
        break
    fi
done

if [ "${found}" -ne "1" ]; then
    echo "$project project doesn't use clang-format"
    exit 0
fi

################################################################################
# Ensure that the correct ".clang-format" file is used
################################################################################
if ! cd ${dot_clang_format_file_src_repo_dir}; then
    echo "$srv_err Can't cd into ${dot_clang_format_file_src_repo_dir}" >&2
    exit 1
fi

# get the latest version of the file in the branch
# need to preserves all trailing newlines '; printf x); $var=${a%x}'
dot_clang_format_file_out="$(git show \
    ${dot_clang_format_file_src_repo_branch}:${dot_clang_format_file_src}; printf x)"
if [ "$?" -ne "0" ]; then
    echo "$srv_err 'git show" \
        "${dot_clang_format_file_src_repo_branch}:${dot_clang_format_file_src}'" \
        "returned with error" >&2
    exit 1
fi
if [ -z "${dot_clang_format_file_out}" ]; then
    echo "$srv_err 'dot_clang_format_file_out' var is empty" >&2
    exit 1
fi

dot_clang_format_file_out=${dot_clang_format_file_out%x}

# create a '.clang-format' file if there is none, or if it's different
create_file="0"
if [ ! -f "${dot_clang_format_file_dest}" ]; then
    create_file="1"
else
    cmp -s ${dot_clang_format_file_dest} <(printf "%s" "${dot_clang_format_file_out}")
    [ "$?" -ne "0" ] && create_file="1"
fi

if [ "${create_file}" -ne "0" ]; then
    printf "%s" "${dot_clang_format_file_out}" >${dot_clang_format_file_dest}
    if [ "$?" -ne "0" ]; then
        echo "$srv_err Can't create ${dot_clang_format_file_dest}" >&2
        exit 1
    fi
fi

################################################################################
#   Check formatting
################################################################################
git_repo_dir="${repo_root_dir}/${git_repo}.git"
if ! cd ${git_repo_dir}; then
    echo "$srv_err Can't change dir to $git_repo_dir" >&2
    exit 1
fi

# git list all files in the commit
files=($(git diff-tree --no-commit-id --name-only -r ${commit}))
if [ "$?" -ne "0" ]; then
    echo "$srv_err 'git diff-tree --no-commit-id --name-only -r ${commit}'" \
        "returned with error" >&2
    exit 1
fi

bad_formatting="0"
error_out="Wrong formatting"$'\n'
for f in "${files[@]}"; do
    if [[ ! "${f}" =~ \.${file_extensions}$ ]]; then
        echo "Skip file: ${f}"
        continue
    fi

    file_out=$(git show ${commit}:${f})
    formatted_out=$(echo "${file_out}" | ${clang_format_bin} \
        -style=file -fallback-style=none -assume-filename=${f})

    diff_res="$(diff -u  <(printf "%s" "${file_out}") <(printf "%s" "${formatted_out}"))"
    if [ -n "${diff_res}" ]; then
        bad_formatting="1"
        error_out+="file: ${f}"$'\n'
        error_out+="${diff_res}"
        break
    fi
done

if [ "${bad_formatting}" -ne "0" ]; then
    echo "***Error start***" >&2
    echo "${error_out}" >&2
    echo "***Error end***" >&2
    exit 1
fi
