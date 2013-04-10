#!/bin/bash
# Source this script.
# Given "-2" as option uses python2.
# Given "-v" as option tries to be more verbose.

# This script uses distributes develop command to create a dev environment where
# python distribution package under the same directory as this script can be
# imported and should be preferred for import before installed packages with same name.
#
# If package with same name is also installed then this does not always work and the installed
# package is imported instead. This can happen if distribution package contains namespace
# packages for example.

# This check must be the first line
[[ $_ != $0 ]] || { echo "Error: source this script." 1>&2; exit 1; }

# Adds the $2 param to the beginning of the $1 variable
addToVarBeg() {
    export $1="${2}${!1}"
}

# Check if PATH contains given path already in the beginning.
# $1: content which is checked against PATH variable.
# $2: Alternative PATH like variable to work on, default is the "PATH"
check_if_already_in_path_beg() {
    local _path_var="PATH"
    [ -n "${2}" ] && _path_var="${2}"

    if ! $(\grep -qE "^:?${1}(:|$)" <(echo "${!_path_var}")); then
        return 1 # was not
    fi
    return 0 # was
}

# Gets current scripts path when given "${BASH_SOURCE[0]}" as parameter
# $1? Optional "--no-follow" option to stop symlink following.
# $1: Script path.
# $2: Parameter name where script path is to be stored.
get_script_path() {
    local no_follow=""
    local script_path=""
    [[ "${1}" == "--no-follow" ]] && { no_follow="yes"; shift; }
    [[ "${1}" && "${2}" ]] || { echo "ERROR: get_script_path needs two parameters." 1>&2; return 1; }

    # Get script path
    script_path="${1}";

    # Unlink path if not --no-follow given
    if [[ "${no_follow}" != "yes" && -h "${script_path}" ]]; then
        while [[ -h "${script_path}" ]]; do script_path=$(readlink "${script_path}"); done
    fi

    # Absolutify path
    {
        pushd .
        cd "$(dirname "${script_path}")"
        script_path="$(pwd)"
        popd
    } > /dev/null

    printf -v "${2}" "%s" "${script_path}"
}

# Adds the $1 param to the beginning of PATH variable
# $1:
# $2: Alternative PATH like variable to work on, default is the "PATH"
addToPathBeg() {
    if ! check_if_already_in_path_beg ${1} ${2}; then
        local _path_var="PATH"
        [ -n "${2}" ] && _path_var="${2}"
        if [[ "${!_path_var}" ]]; then
            addToVarBeg "${_path_var}" "${1}:"
        else
            # In case if path variable is empty
            printf -v "${_path_var}" "%s" "${1}"
        fi
    fi
}

# Clean-up function
# $1: Return value
cleanup() {
    if [[ "${_path_changed}" == "true" ]]; then
        popd > /dev/null
    fi

    # Avoid shell environment namespace pollution
    unset -v _path_changed
    unset -f cleanup addToPathBeg get_script_path check_if_already_in_path_beg addToVarBeg main vecho

    return ${1}
}

vecho() {
   (( VERBOSE > 0 )) && echo $@
}

main() {
    local TMP_BASE_PATH="/tmp"
    local PYTHON_BIN="python"
    local SCRIPT_PATH
    local DEV_INSTALL_DIR
    local VERBOSE=0

    # Process command line arguments
    local check_count=2
    while [[ "${@}" ]] && (( check_count > 0)); do
        # Explicitly use python 2 if "-2" given as option
        [[ "${1}" == "-2" ]] && { shift; PYTHON_BIN="python2"; }
        # Be more verbose if "-v" given
        [[ "${1}" == "-v" ]] && { shift; VERBOSE=1; }
        (( --check_count ))
    done

    get_script_path --no-follow "${BASH_SOURCE[0]}" SCRIPT_PATH
    vecho "This script was is located at '${SCRIPT_PATH}'."

    # Check if setup.py is located at script path
    local _setup="setup.py"
    [[ -e "${SCRIPT_PATH}/${_setup}" ]] || { echo "Error: No '${_setup}' found from: ${SCRIPT_PATH}." 1>&2; cleanup 1; return $?; }

    # Change dir to SCRIPT_PATH if needed
    if [[ "$(pwd)" != "${SCRIPT_PATH}" ]]; then
        pushd . > /dev/null
        cd "${SCRIPT_PATH}"
        _path_changed="true" # global var
    fi

    # Get tmp dev install path
    DEV_INSTALL_DIR="${TMP_BASE_PATH}/$(${PYTHON_BIN} ${_setup} --name)-dev-${PYTHON_BIN}" || {
        local retval=$?
        echo "Error: Running ${_setup} from '${SCRIPT_PATH}' failed." 1>&2
        vecho "The command was: '${PYTHON_BIN} ${_setup} --name)-dev-${PYTHON_BIN}'."
        return ${retval}
    }

    mkdir -p "${DEV_INSTALL_DIR}" || { cleanup 1; return $?; }

    vecho "Adding path '${DEV_INSTALL_DIR}' to PYTHONPATH."
    addToPathBeg $DEV_INSTALL_DIR PYTHONPATH
    vecho "Adding path '${DEV_INSTALL_DIR}' to PATH."
    addToPathBeg $DEV_INSTALL_DIR
    export PYTHONPATH
    vecho "Current PYTHONPATH: ${PYTHONPATH}"

    vecho "Running command: ${PYTHON_BIN} ${_setup} develop -d $DEV_INSTALL_DIR"
    ${PYTHON_BIN} ${_setup} develop -d $DEV_INSTALL_DIR
    cleanup 0
}

declare _path_changed="false"

main "${@}"
