#!/bin/bash
################################################################################
# This is a gerrit commit received hook.
#
# SPECIFICS:
#     - Some variables may be split into declaration and initialization.
#       In case of local variable the return code from a subshell is replaced
#       with a return code from the operation of making a variable 'local'
#       (almost always '0').
################################################################################

this_script_dir="$(cd "$(dirname "${0}")" >/dev/null 2>&1 && pwd)"
this_script_name="$(basename "${0}")"
this_script_path="${this_script_dir}/${this_script_name}"

srv_err="Error occured on the server"

# do not print anything to 'stdout' here, the result may be assigned to a variable
cmd_do() {
    eval "$@" || { echo "${srv_err}. ${this_script_path}: cmd failed '$@'" >&2; exit 1; }
}

# do not print anything to 'stdout' here, the result may be assigned to a variable
cmd_do_nonfatal() {
    eval "$@" || { echo "${srv_err}. ${this_script_path}: cmd failed '$@'" >&2; return 1; }
}

#
# Parse script args.
#
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
    #
    # Set all needed variables.
    #
    # path to the root dir with bare git repos
    local repo_root_dir=""
    # path to the repo with clang-format stuff
    local checker_repo_dir="${repo_root_dir}/<path_to_repo>.git"
    # path from the repo root to the checker
    local checker_file_src="clang-format/server_side/git-bare-clang-format-checker.sh"

    #
    # Validate received refname.
    #
    # name of the branch to check for clang-format stuff presence
    local checker_repo_branch=""
    local refname_mask="refs/heads/"
    if [[ ${refname} =~ ^${refname_mask} ]]; then
        checker_repo_branch="${refname#${refname_mask}}"
    else
        #echo "refname '${refname}' doesn't match '${refname_mask}'"
        return 0
    fi

    #
    # Get the latest version of the checker from the branch.
    # Every branch may have a different version of the checker, or may not have it at all.
    # Skip format checking if the checker is not in the branch.
    #
    cmd_do pushd ${checker_repo_dir} >/dev/null
    local checker_file_out
    checker_file_out="$(cmd_do env -u GIT_DIR git show \
        ${checker_repo_branch}:${checker_file_src} 2>/dev/null)" || exit 0
    cmd_do popd >/dev/null

    #
    # Create a tmp file for this version of checker.
    #
    checker="$(cmd_do mktemp -t ${checker_file_src##*/}.XXXXXXXXXX)" || exit 1
    trap 'rm -f -- "${checker}"' INT TERM HUP EXIT
    cmd_do 'printf "%s" "${checker_file_out}"' >${checker} || exit 1

    #
    # Run cpp code formatting checker.
    #
    /bin/bash ${checker} --git-repo ${project} --commit ${newrev} --branch ${checker_repo_branch}
    [ "$?" -eq "0" ] || exit 1
}
check_cpp_code_formatting
