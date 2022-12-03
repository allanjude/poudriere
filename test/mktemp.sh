set -e
. common.sh
set +e

unset TMPDIR
assert '' "${TMPDIR-}"
assert_not '' "${POUDRIERE_TMPDIR-}"

{
	assert_ret 0 [ -n "${POUDRIERE_TMPDIR}" ]
	tmp=$(mktemp -u)
	assert "${POUDRIERE_TMPDIR}" "${tmp%/*}"
	assert_ret_not 0 [ -e "${tmp}" ]
}

{
	mkdir_tmpdir=$(mktemp -d)
	assert_ret 0 [ -d "${mkdir_tmpdir}" ]
	tmp=$(TMPDIR=${mkdir_tmpdir} mktemp -u)
	assert_ret_not 0 [ -e "${tmp}" ]
	assert_not "${POUDRIERE_TMPDIR}" "${tmp%/*}"
	assert "${mkdir_tmpdir}" "${tmp%/*}"
	rm -rf "${mkdir_tmpdir}"
}

{
	# mktemp has special handling for MNT_DATADIR being set but it
	# must also exist first.
	STATUS=1
	MNT_DATADIR=$(mktemp -udt mnt_datadir)
	echo "MNT_DATADIR=${MNT_DATADIR}" >&2
	datatmpdir="${MNT_DATADIR}/tmp"
	assert_ret_not 0 [ -e "${datatmpdir}" ]
	assert_ret 0 [ -n "${POUDRIERE_TMPDIR}" ]
	tmp=$(mktemp -u)
	assert "${POUDRIERE_TMPDIR}" "${tmp%/*}"
	assert_not "${datatmpdir}" "${tmp%/*}"
	assert_ret_not 0 [ -e "${tmp}" ]

	mkdir -p "${datatmpdir}"
	assert_ret 0 [ -d "${datatmpdir}" ]
	tmp=$(mktemp -u)
	assert_not "${POUDRIERE_TMPDIR}" "${tmp%/*}"
	assert "${datatmpdir}" "${tmp%/*}"
	assert_ret_not 0 [ -e "${tmp}" ]
	rm -rf "${MNT_DATADIR}"
	unset STATUS MNT_DATADIR
}

{
	# mktemp has special handling for MNT_DATADIR being set but it
	# must also exist first, and TMPDIR still overrides it.
	STATUS=1
	MNT_DATADIR=$(mktemp -udt mnt_datadir)
	echo "MNT_DATADIR=${MNT_DATADIR}" >&2
	datatmpdir="${MNT_DATADIR}/tmp"
	mkdir -p "${datatmpdir}"
	assert_ret 0 [ -e "${datatmpdir}" ]
	assert_ret 0 [ -n "${POUDRIERE_TMPDIR}" ]
	mkdir_tmpdir=$(mktemp -d)
	assert_ret 0 [ -d "${datatmpdir}" ]
	tmp=$(TMPDIR=${mkdir_tmpdir} mktemp -u)
	assert_not "${POUDRIERE_TMPDIR}" "${tmp%/*}"
	assert_not "${datatmpdir}" "${tmp%/*}"
	assert "${mkdir_tmpdir}" "${tmp%/*}"
	rm -rf "${mkdir_tmpdir}" "${datatmpdir}"
	unset STATUS MNT_DATADIR
}

# Once STATUS is 0 then MNT_DATADIR should not be used.
{
	# mktemp has special handling for MNT_DATADIR being set but it
	# must also exist first.
	STATUS=0
	MNT_DATADIR=$(mktemp -udt mnt_datadir)
	echo "MNT_DATADIR=${MNT_DATADIR}" >&2
	datatmpdir="${MNT_DATADIR}/tmp"
	assert_ret_not 0 [ -e "${datatmpdir}" ]
	assert_ret 0 [ -n "${POUDRIERE_TMPDIR}" ]
	tmp=$(mktemp -u)
	assert "${POUDRIERE_TMPDIR}" "${tmp%/*}"
	assert_not "${datatmpdir}" "${tmp%/*}"
	assert_ret_not 0 [ -e "${tmp}" ]

	mkdir -p "${datatmpdir}"
	assert_ret 0 [ -d "${datatmpdir}" ]
	tmp=$(mktemp -u)
	assert "${POUDRIERE_TMPDIR}" "${tmp%/*}"
	assert_not "${datatmpdir}" "${tmp%/*}"
	assert_ret_not 0 [ -e "${tmp}" ]
	rm -rf "${MNT_DATADIR}"
	unset STATUS MNT_DATADIR
}

# Once STATUS is 0 then MNT_DATADIR should not be used.
{
	# mktemp has special handling for MNT_DATADIR being set but it
	# must also exist first, and TMPDIR still overrides it.
	STATUS=0
	MNT_DATADIR=$(mktemp -udt mnt_datadir)
	echo "MNT_DATADIR=${MNT_DATADIR}" >&2
	datatmpdir="${MNT_DATADIR}/tmp"
	mkdir -p "${datatmpdir}"
	assert_ret 0 [ -e "${datatmpdir}" ]
	assert_ret 0 [ -n "${POUDRIERE_TMPDIR}" ]
	mkdir_tmpdir=$(mktemp -d)
	assert_ret 0 [ -d "${datatmpdir}" ]
	tmp=$(TMPDIR=${mkdir_tmpdir} mktemp -u)
	assert_not "${POUDRIERE_TMPDIR}" "${tmp%/*}"
	assert_not "${datatmpdir}" "${tmp%/*}"
	assert "${mkdir_tmpdir}" "${tmp%/*}"
	rm -rf "${mkdir_tmpdir}" "${datatmpdir}"
	unset STATUS MNT_DATADIR
}
