# This file adds the functions to build SystemTap
# Copyright 2022 Christoph Muellner <christoph.muellner@vrull.eu>
# Licensed under the GPL v2. See COPYING in the root of this package

do_systemtap_get() { :; }
do_systemtap_extract() { :; }
do_systemtap_for_build() { :; }
do_systemtap_for_host() { :; }
do_systemtap_for_target() { :; }

# Overide functions depending on configuration
if [ "${CT_SYSTEMTAP_TARGET}" = "y" -o  "${CT_SYSTEMTAP}" = "y" ]; then

# Download SYSTEMTAP
do_systemtap_get() {
    CT_Fetch SYSTEMTAP
}

# Extract SYSTEMTAP
do_systemtap_extract() {
    CT_ExtractPatch SYSTEMTAP
}

# Build SYSTEMTAP for running on build
# - always build statically
# - install in build-tools prefix
do_systemtap_for_build() {
    local -a systemtap_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing SYSTEMTAP for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-systemtap-build-${CT_BUILD}"

    systemtap_opts+=( "host=${CT_BUILD}" )
    systemtap_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    systemtap_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    systemtap_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    do_systemtap_backend "${systemtap_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build SYSTEMTAP for running on host
do_systemtap_for_host() {
    local -a systemtap_opts

    CT_DoStep INFO "Installing SYSTEMTAP for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-systemtap-host-${CT_HOST}"

    systemtap_opts+=( "host=${CT_HOST}" )
    systemtap_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    systemtap_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    systemtap_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    do_systemtap_backend "${systemtap_opts[@]}"

    CT_Popd
    CT_EndStep
}

if [ "${CT_SYSTEMTAP_TARGET}" = "y" ]; then
do_systemtap_for_target() {
    local -a systemtap_opts

    CT_DoStep INFO "Installing SYSTEMTAP for target"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-systemtap-target-${CT_HOST}"

    systemtap_opts+=( "host=${CT_TARGET}" )
    case "${CT_TARGET}" in
        *-*-mingw*)
            prefix="/mingw"
            ;;
        *)
            prefix="/usr"
            ;;
    esac
    systemtap_opts+=( "cflags=${CT_ALL_TARGET_CFLAGS}" )
    systemtap_opts+=( "prefix=${prefix}" )
    systemtap_opts+=( "destdir=${CT_SYSROOT_DIR}" )
    systemtap_opts+=( "shared=${CT_SHARED_LIBS}" )
    do_systemtap_backend "${systemtap_opts[@]}"

    CT_Popd
    CT_EndStep
}
fi

# Build SYSTEMTAP
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
#     destdir       : install destination       : dir       : (none)
do_systemtap_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg
    local -a extra_config

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring SYSTEMTAP"

    # To avoind “illegal text-relocation” linking error against
    # the static library, see:
    #     https://github.com/Homebrew/homebrew-core/pull/25470
    case "${host}" in
        *darwin*)
            extra_config+=("--with-pic")
            ;;
    esac

    # FIXME: SYSTEMTAP's configure script doesn't respect the host parameter
    # when not cross-compiling, ie when build == host.
    CT_DoExecLog CFG                                \
    CC="${host}-gcc"                                \
    CFLAGS="${cflags} -fexceptions"                 \
    LDFLAGS="${ldflags}"                            \
    ${CONFIG_SHELL}                                 \
    "${CT_SRC_DIR}/systemtap/configure"                   \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --prefix="${prefix}"                        \
        --disable-shared                            \
        --enable-static                             \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building SYSTEMTAP"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        if [ "${host}" = "${CT_BUILD}" ]; then
            CT_DoLog EXTRA "Checking SYSTEMTAP"
            CT_DoExecLog ALL make ${CT_JOBSFLAGS} -s check
        else
            # Cannot run host binaries on build in a canadian cross
            CT_DoLog EXTRA "Skipping check for SYSTEMTAP on the host"
        fi
    fi

    CT_DoLog EXTRA "Installing SYSTEMTAP"
    CT_DoExecLog ALL make install DESTDIR="${destdir}"
}

fi # CT_SYSTEMTAP
