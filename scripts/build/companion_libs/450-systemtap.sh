# This file adds the functions to build SystemTap
# Copyright 2022 Christoph Muellner <christoph.muellner@vrull.eu>
# Licensed under the GPL v2. See COPYING in the root of this package

do_systemtap_get() { :; }
do_systemtap_extract() { :; }
do_systemtap_for_build() { :; }
do_systemtap_for_host() { :; }
do_systemtap_headers() { :; }
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

if [ "${CT_SYSTEMTAP}" = "y" ]; then
# We don't need SystemTap for build

do_systemtap_for_host() {
    local -a systemtap_opts

    CT_DoStep INFO "Installing SystemTap for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-systemtap-host-${CT_HOST}"

    systemtap_opts+=( "host=${CT_HOST}" )
    systemtap_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    systemtap_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    systemtap_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )

    do_systemtap_backend "${systemtap_opts[@]}"

    CT_Popd
    CT_EndStep
}
fi

if [ "${CT_SYSTEMTAP_TARGET}" = "y" ]; then

# SystemTap's configure expects a working toolchain incl. glibc.
# However, glibc needs SystemTap headers to enable the stap probes.
# The header file sdt-config.h needs a configure test to be generated.
# Let's break this cyclic dependency, by assuming a failing configure
# test and generating sdt-config.h from here.
# The later installation will fix that in the sysroot.
do_systemtap_headers() {
    CT_DoStep INFO "CT_SRC_DIR: ${CT_SRC_DIR}"
    CT_DoStep INFO "CT_SYSROOT_DIR: ${CT_SYSROOT_DIR}"
    mkdir -p "${CT_SYSROOT_DIR}/usr/include/sys/"
    cp "${CT_SRC_DIR}/systemtap/includes/sys/sdt.h" \
       "${CT_SYSROOT_DIR}/usr/include/sys/"
    echo "#define _SDT_ASM_SECTION_AUTOGROUP_SUPPORT 1" > \
         "${CT_SYSROOT_DIR}/usr/include/sys/sdt-config.h"
    CT_EndStep
}

do_systemtap_for_target() {
    local -a systemtap_opts
    local prefix

    CT_DoStep INFO "Installing SystemTap for target"
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

# Configure SYSTEMTAP
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

    if [ "${shared}" != "y" ]; then
        extra_config+=("--disable-shared")
    fi

    CT_DoLog EXTRA "Configuring SystemTap"

    CT_DoExecLog CFG                                \
    CFLAGS="${cflags}"                              \
    LDFLAGS="${ldflags}"                            \
    ${CONFIG_SHELL}                                 \
    "${CT_SRC_DIR}/systemtap/configure"             \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --prefix="${prefix}"                        \
        --enable-static                             \
        --without-python2-probes                    \
        --without-python3-probes                    \
        --without-debuginfod                        \
        --without-nss                               \
        --without-openssl                           \
        --disable-sqlite                            \
        --without-avahi                             \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building SystemTap"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}
    CT_DoLog EXTRA "Installing SystemTap"
    CT_DoExecLog ALL make install DESTDIR="${destdir}"
}

fi # CT_SYSTEMTAP
