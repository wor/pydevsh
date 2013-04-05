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
[[ $_ != $0 ]] || { echo "Error: source this script."; exit 1; }

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
# $1: "${BASH_SOURCE[0]}"
# $2: parameter name where script path is to be stored
Get_script_path() {
    [[ "${1}" && "${2}" ]] || { echo "ERROR: Get_script_path needs two parameters." 1>&2; return 1; }

    # get script path
    local script_path="${1}";

    # unlink path
    if [ -h "${script_path}" ]; then
        while [ -h "${script_path}" ]; do script_path=`readlink "${script_path}"`; done
    fi

    pushd . > /dev/null
    cd "$(dirname "${script_path}")" > /dev/null
    script_path="$(pwd)";
    popd  > /dev/null

    eval "${2}"="\${script_path}"
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

# Clean up function
# $1: return value
quit() {
    if [[ "${_path_changed}" == "true" ]]; then
        popd > /dev/null
    fi

    # Avoid shell environment namespace pollution
    unset -v _path_changed
    unset -f quit addToPathBeg Get_script_path check_if_already_in_path_beg addToVarBeg main

    return ${1}
}

main() {
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

    Get_script_path "${BASH_SOURCE[0]}" SCRIPT_PATH
    DEV_INSTALL_DIR="/tmp/$(cd ${SCRIPT_PATH}; ${PYTHON_BIN} setup.py --name)-dev-${PYTHON_BIN}"

    (( VERBOSE > 0 )) && echo "This script was is located at '${SCRIPT_PATH}'."
    if [[ "$(pwd)" != "${SCRIPT_PATH}" ]]; then
        pushd . > /dev/null
        cd "${SCRIPT_PATH}"
        _path_changed="true"
    fi

    _setup="setup.py"
    [ -e "${_setup}" ] || { echo "No ${_setup} found from: $(pwd)."; quit 1; }

    mkdir -p "${DEV_INSTALL_DIR}" || quit 1

    (( VERBOSE > 0 )) && echo "Adding path '${DEV_INSTALL_DIR}' to PYTHONPATH."
    addToPathBeg $DEV_INSTALL_DIR PYTHONPATH
    (( VERBOSE > 0 )) && echo "Adding path '${DEV_INSTALL_DIR}' to PATH."
    addToPathBeg $DEV_INSTALL_DIR
    export PYTHONPATH
    (( VERBOSE > 0 )) && echo "Current PYTHONPATH: ${PYTHONPATH}"

    (( VERBOSE > 0 )) && echo "Running command: ${PYTHON_BIN} ${_setup} develop -d $DEV_INSTALL_DIR"
    ${PYTHON_BIN} ${_setup} develop -d $DEV_INSTALL_DIR
}

declare _path_changed="false"

main "${@}"
quit $?
