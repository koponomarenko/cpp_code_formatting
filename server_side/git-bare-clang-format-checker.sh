#!/bin/bash
################################################################################
# This script checks formatting of all files with certain file extensions
# in the commit.
#
# SPECIFICS:
#     - The whole file is checked.
#     - .clang-format file is obtained from a branch in '--branch' argument.
#
#     - Some variables may be split into declaration and initialization.
#       In case of local variable the return code from a subshell is replaced
#       with a return code from the operation of making a variable 'local'
#       (almost always '0').
################################################################################

srv_err="Error occured on the server"

# do not print anything to 'stdout' here, the result may be assigned to a variable
cmd_do() {
    eval "$@" || { echo "${srv_err}. $(realpath -s "${BASH_SOURCE[0]}"): cmd failed '$@'" >&2; exit 1; }
}

# do not print anything to 'stdout' here, the result may be assigned to a variable
cmd_do_nonfatal() {
    eval "$@" || { echo "${srv_err}. $(realpath -s "${BASH_SOURCE[0]}"): cmd failed '$@'" >&2; return 1; }
}

log_err() {
    echo "${srv_err}. $(realpath -s "${BASH_SOURCE[0]}"): $@" >&2
}

################################################################################
# Set all needed variables.
################################################################################
clang_format_bin="/opt/dev_tools/bin/clang-format"
# path to the root dir with bare git repos
repo_root_dir=""
# absolute path to a repo with '.clang-format' file
dot_clang_format_file_src_repo_dir="${repo_root_dir}/<path_to_repo>.git"
# path from the repo root to the '.clang-format' file
dot_clang_format_file_src="clang-format/dot-clang-format"

file_extensions="(cpp|h|hpp|c|c\+\+|cc|hh|cxx|hxx|C|H)"

################################################################################
#   Parse script args
################################################################################
while [[ $# -gt 0 ]]; do
    key="${1}"
    case ${key} in
        --git-repo)
            git_repo="${2}"
            shift # past argument
            shift # past value
            ;;
        --commit)
            commit="${2}"
            shift # past argument
            shift # past value
            ;;
        --branch)
            branch="${2}"
            shift # past argument
            shift # past value
            ;;
        *) # unknown option
            shift # past argument
            ;;
    esac
done

################################################################################
#   Check environment
################################################################################
if [ -z "${BASH}" ]; then
    log_err "This shell is not bash shell"
    exit 1
fi

set -o pipefail

cmd_do which diff >/dev/null
cmd_do which git >/dev/null

if [ ! -f "${clang_format_bin}" ]; then
    log_err "clang-format not found!"
    exit 1
fi

clang_format_version="7.0.1"
if ! ${clang_format_bin} -version | grep -q "version ${clang_format_version}"; then
    log_err "clang-format must be version ${clang_format_version}!"
    log_err "current version is: $(${clang_format_bin} -version)"
    exit 1
fi

# in other case all git commands will be called from this dir.
unset GIT_DIR

################################################################################
#   Get a list of repositories for formatting check
################################################################################
cmd_do cd ${dot_clang_format_file_src_repo_dir}
repos_to_check_cpp_formatting_file="clang-format/server-side/repos-to-check-cpp-formatting"
repos_to_check_cpp_formatting_out="$(cmd_do git show \
    ${branch}:${repos_to_check_cpp_formatting_file})" || exit 1

. <(cmd_do 'printf "%s" "${repos_to_check_cpp_formatting_out}"') || exit 1

################################################################################
#   Check if this repo is in the list of repositories for formatting check
################################################################################
[ ! -z ${projects+x} ] || { log_err "'\${projects}' array is not set"; exit 1; }

found="0"
for i in "${projects[@]}"; do
    if [[ "${i}" == "${git_repo}" ]]; then
        found="1" && break
    fi
done

if [ "${found}" -eq "0" ]; then
    #echo "${git_repo} project doesn't use clang-format"
    exit 0
fi

################################################################################
#   Get the latest version of the ".clang-format" file
################################################################################
cmd_do cd ${dot_clang_format_file_src_repo_dir}
# to preserves all trailing newlines this workaround is used:
#     a=$(printf 'test\n\n'; printf x); a=${a%x}
dot_clang_format_file_out="$(cmd_do git show \
    ${branch}:${dot_clang_format_file_src}; printf x)" || exit 1
dot_clang_format_file_out=${dot_clang_format_file_out%x}

tmp_dir=""
tmp_dir="$(cmd_do mktemp -d -t dot-clang-format.XXXXXXXXXX)" || exit 1
trap 'rm -rf -- "${tmp_dir}"' INT TERM HUP EXIT
cmd_do 'printf "%s" "${dot_clang_format_file_out}"' >${tmp_dir}/.clang-format || exit 1

################################################################################
#   Check formatting
################################################################################
cmd_do cd "${repo_root_dir}/${git_repo}.git"

# list all files in the commit
declare -a files
files=($(cmd_do git diff-tree --no-commit-id --name-only --diff-filter=d -r ${commit})) || exit 1

bad_formatting="0"
error_out="Wrong formatting!"$'\n'
file_out=""
formatted_out=""
for f in "${files[@]}"; do
    if [[ ! "${f}" =~ \.${file_extensions}$ ]]; then
        #echo "Skip file: ${f}"
        continue
    fi

    file_out="$(cmd_do git show ${commit}:${f})" || exit 1
    cmd_do pushd ${tmp_dir} >/dev/null
    formatted_out="$(cmd_do 'echo "${file_out}" | ${clang_format_bin} \
        -style=file -fallback-style=none -assume-filename=${f}')" || exit 1
    cmd_do popd >/dev/null

    diff_res="$(diff -u  <(printf "%s" "${file_out}") <(printf "%s" "${formatted_out}"))"
    rc="$?"
    if [ "${rc}" -eq "1" ]; then
        bad_formatting="1"
        error_out+="file: ${f}"$'\n'
        error_out+="${diff_res}"
        break
    elif [ "${rc}" -eq "2" ]; then
        log_err "diff returned with error while diffing file '${f}' in commit '${commit}'"
        exit 1
    fi
done

if [ "${bad_formatting}" -ne "0" ]; then
    echo "*** Error start ***" >&2
    echo "${error_out}" >&2
    echo "*** Error end ***" >&2
    exit 1
fi
