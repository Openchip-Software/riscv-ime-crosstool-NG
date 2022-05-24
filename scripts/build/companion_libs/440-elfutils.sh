# This file adds the functions to build elfutils
# Copyright 2022 Christoph Muellner <christoph.muellner@vrull.eu>
# Licensed under the GPL v2. See COPYING in the root of this package

do_elfutils_get() { :; }
do_elfutils_extract() { :; }
do_elfutils_for_build() { :; }
do_elfutils_for_host() { :; }
do_elfutils_headers() { :; }
do_elfutils_for_target() { :; }

# Overide functions depending on configuration
if [ "${CT_ELFUTILS_TARGET}" = "y" -o  "${CT_ELFUTILS}" = "y" ]; then

# Download ELFUTILS
do_elfutils_get() {
    CT_Fetch ELFUTILS
}

# Extract ELFUTILS
do_elfutils_extract() {
    CT_ExtractPatch ELFUTILS
}

if [ "${CT_ELFUTILS}" = "y" ]; then
# We don't need elfutils for build

do_elfutils_for_host() {
    local -a elfutils_opts

    CT_DoStep INFO "Installing elfutils for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-elfutils-host-${CT_HOST}"

    elfutils_opts+=( "host=${CT_HOST}" )
    elfutils_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    elfutils_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    elfutils_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )

    do_elfutils_backend "${elfutils_opts[@]}"

    CT_Popd
    CT_EndStep
}
fi

if [ "${CT_ELFUTILS_TARGET}" = "y" ]; then
do_elfutils_for_target() {
    local -a elfutils_opts
    local prefix

    CT_DoStep INFO "Installing elfutils for target"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-elfutils-target-${CT_HOST}"

    elfutils_opts+=( "host=${CT_TARGET}" )
    case "${CT_TARGET}" in
        *-*-mingw*)
            prefix="/mingw"
            ;;
        *)
            prefix="/usr"
            ;;
    esac
    elfutils_opts+=( "cflags=${CT_ALL_TARGET_CFLAGS}" )
    elfutils_opts+=( "prefix=${prefix}" )
    elfutils_opts+=( "destdir=${CT_SYSROOT_DIR}" )
    elfutils_opts+=( "shared=${CT_SHARED_LIBS}" )

    do_elfutils_backend "${elfutils_opts[@]}"

    CT_Popd
    CT_EndStep
}
fi

# Configure ELFUTILS
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
#     destdir       : install destination       : dir       : (none)
do_elfutils_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg
    local -a extra_config

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    if [ "${shared}" != "y" ]; then
        extra_config+=("--disable-shared")
    fi

    CT_DoLog EXTRA "Configuring elfutils"

    CT_DoExecLog CFG                                \
    CFLAGS="${cflags}"                              \
    LDFLAGS="${ldflags}"                            \
    ${CONFIG_SHELL}                                 \
    "${CT_SRC_DIR}/elfutils/configure"              \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --prefix="${prefix}"                        \
	--disable-textrelcheck                      \
	--disable-libdebuginfod                     \
	--disable-debuginfod                        \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building elfutils"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}
    CT_DoLog EXTRA "Installing elfutils"
    CT_DoExecLog ALL make install DESTDIR="${destdir}"
}

fi # CT_ELFUTILS
