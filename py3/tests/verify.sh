#!/bin/bash -i
#
# Smoke tests for bisos.sbom:
#   pkgsSeed  -- NpmPkg, PipPkg, AptPkg, SbomSpec, PkgsSeedInfo, factories, setup()
#   sbom_csu  -- all CS command classes present and callable
#   exmpl-featured-sbom.pcs -- example menu runs without error
#
# Non-invasive: does NOT run apt install, pip install, npm install, or sbom_fullUpdate.
#
# Run from the tests/ directory:
#   cd py3/tests && ./verify.sh

# Safety check: must run from a directory named "tests"
if [[ "$(basename "$PWD")" != "tests" ]]; then
    echo "ERROR: verify.sh must be run from a directory named 'tests'." >&2
    echo "  Current PWD: $PWD" >&2
    exit 1
fi

# --- Example menu: runs without error (non-invasive) ---

lpDo ../bin/exmpl-featured-sbom.pcs

# --- pkgsSeed: public API surface ---

lpDo python3 -c "
from bisos.sbom import pkgsSeed as m
import sys

failed = 0
symbols = [
    # classes
    'AptPkg', 'PipPkg', 'NpmPkg', 'SbomSpec', 'PkgsSeedInfo',
    # factory functions
    'aptPkg', 'pipPkg', 'npmPkg', 'sbomSpec', 'setup',
    # singleton
    'pkgsSeedInfo',
    # utility
    'plantWithWhich',
]
for sym in symbols:
    if not hasattr(m, sym):
        print(f'  [FAIL] pkgsSeed missing: {sym}'); failed += 1
    else:
        print(f'  [PASS] pkgsSeed has: {sym}')

sys.exit(failed)
"

# --- pkgsSeed: NpmPkg class attributes ---

lpDo python3 -c "
from bisos.sbom.pkgsSeed import NpmPkg
import sys

failed = 0
pkg = NpmPkg(name='gatsby', ver='5.0.0', scope='local')
for attr, expected in [('name', 'gatsby'), ('ver', '5.0.0'), ('scope', 'local'), ('func', None)]:
    got = getattr(pkg, attr)
    if got != expected:
        print(f'  [FAIL] NpmPkg.{attr}: got {got!r}, expected {expected!r}'); failed += 1
    else:
        print(f'  [PASS] NpmPkg.{attr} = {got!r}')

# default scope is global
pkg2 = NpmPkg(name='typescript')
if pkg2.scope != 'global':
    print(f'  [FAIL] NpmPkg default scope: got {pkg2.scope!r}, expected \"global\"'); failed += 1
else:
    print(f'  [PASS] NpmPkg default scope = \"global\"')

sys.exit(failed)
"

# --- pkgsSeed: npmPkg() factory ---

lpDo python3 -c "
from bisos.sbom.pkgsSeed import npmPkg, NpmPkg
import sys

failed = 0
pkg = npmPkg('gatsby', ver='5.0.0', scope='local')
if not isinstance(pkg, NpmPkg):
    print(f'  [FAIL] npmPkg() returns wrong type: {type(pkg)}'); failed += 1
else:
    print(f'  [PASS] npmPkg() returns NpmPkg instance')

for attr, expected in [('name', 'gatsby'), ('ver', '5.0.0'), ('scope', 'local')]:
    got = getattr(pkg, attr)
    if got != expected:
        print(f'  [FAIL] npmPkg().{attr}: got {got!r}, expected {expected!r}'); failed += 1
    else:
        print(f'  [PASS] npmPkg().{attr} = {got!r}')

sys.exit(failed)
"

# --- pkgsSeed: PkgsSeedInfo singleton + setup() round-trips ---

lpDo python3 -c "
from bisos.sbom import pkgsSeed
import sys

failed = 0

# Singleton identity
a = pkgsSeed.PkgsSeedInfo()
b = pkgsSeed.PkgsSeedInfo()
if a is not b:
    print(f'  [FAIL] PkgsSeedInfo is not a singleton'); failed += 1
else:
    print(f'  [PASS] PkgsSeedInfo singleton identity holds')

# setup() with all four pkg types
ap = pkgsSeed.aptPkg
pp = pkgsSeed.pipPkg
npm = pkgsSeed.npmPkg
sbom = pkgsSeed.sbomSpec

pkgsSeed.setup(
    aptPkgsList=[ap('djbdns'), ap('facter')],
    pipPkgsList=[pp('bisos.marmee')],
    npmPkgsList=[npm('gatsby'), npm('typescript', ver='5.0.0', scope='local')],
    sbomsList=[sbom('exmpl-sbom.pcs')],
)
si = pkgsSeed.pkgsSeedInfo

# aptPkgsNames
got = si.aptPkgsNames()
if got != ['djbdns', 'facter']:
    print(f'  [FAIL] aptPkgsNames: got {got}'); failed += 1
else:
    print(f'  [PASS] aptPkgsNames = {got}')

# pipPkgsNames
got = si.pipPkgsNames()
if got != ['bisos.marmee']:
    print(f'  [FAIL] pipPkgsNames: got {got}'); failed += 1
else:
    print(f'  [PASS] pipPkgsNames = {got}')

# npmPkgsNames
got = si.npmPkgsNames()
if got != ['gatsby', 'typescript']:
    print(f'  [FAIL] npmPkgsNames: got {got}'); failed += 1
else:
    print(f'  [PASS] npmPkgsNames = {got}')

# namedNpmPkg
pkg = si.namedNpmPkg('typescript')
if pkg is None or pkg.ver != '5.0.0' or pkg.scope != 'local':
    print(f'  [FAIL] namedNpmPkg(typescript): got {pkg}'); failed += 1
else:
    print(f'  [PASS] namedNpmPkg(typescript) -> ver=5.0.0, scope=local')

# namedNpmPkg for unknown name returns None
pkg = si.namedNpmPkg('nonexistent')
if pkg is not None:
    print(f'  [FAIL] namedNpmPkg(nonexistent) should return None, got {pkg}'); failed += 1
else:
    print(f'  [PASS] namedNpmPkg(nonexistent) = None')

# sbomSpecsNames
got = si.sbomSpecsNames()
if got != ['exmpl-sbom.pcs']:
    print(f'  [FAIL] sbomSpecsNames: got {got}'); failed += 1
else:
    print(f'  [PASS] sbomSpecsNames = {got}')

sys.exit(failed)
"

# --- pkgsSeed: virtenv / pipCmnd / binPath ---

lpDo python3 -c "
from bisos.sbom import pkgsSeed
import sys

failed = 0
si = pkgsSeed.pkgsSeedInfo

# None virtenv -> bare command names
si.virtenv = None
for cmd, expected in [('pip', 'pip'), ('npm', 'npm'), ('python', 'python')]:
    got = si.binPath(cmd)
    if got != expected:
        print(f'  [FAIL] binPath({cmd!r}) with virtenv=None: got {got!r}'); failed += 1
    else:
        print(f'  [PASS] binPath({cmd!r}) virtenv=None -> {got!r}')

# set virtenv -> qualified paths
si.virtenv = '/bisos/venv/py3/asc'
for cmd, expected in [('pip', '/bisos/venv/py3/asc/bin/pip'),
                       ('python', '/bisos/venv/py3/asc/bin/python')]:
    got = si.binPath(cmd)
    if got != expected:
        print(f'  [FAIL] binPath({cmd!r}) with virtenv set: got {got!r}'); failed += 1
    else:
        print(f'  [PASS] binPath({cmd!r}) virtenv set -> {got!r}')

got = si.pipCmnd()
if got != '/bisos/venv/py3/asc/bin/pip':
    print(f'  [FAIL] pipCmnd() with virtenv: got {got!r}'); failed += 1
else:
    print(f'  [PASS] pipCmnd() with virtenv = {got!r}')

si.virtenv = None  # reset
sys.exit(failed)
"

# --- sbom_csu: all CS command classes present ---

lpDo python3 -c "
from bisos.sbom import sbom_csu as m
import sys

failed = 0
commands = [
    'sbom_fullUpdate',
    'aptPkgs_list', 'aptPkg_isInstalled', 'aptPkgs_update',
    'pipPkgs_list', 'pipPkg_isInstalled', 'pipPkgs_update',
    'pipxPkgs_list', 'pipxPkg_isInstalled', 'pipxPkgs_update',
    'npmPkgs_list', 'npmPkg_isInstalled', 'npmPkgs_update',
    'sbomSpecs_list', 'sbomSpec_process', 'sbomSpecs_fullUpdate',
]
for name in commands:
    if not hasattr(m, name):
        print(f'  [FAIL] sbom_csu missing command: {name}'); failed += 1
    else:
        print(f'  [PASS] sbom_csu has command: {name}')

if not hasattr(m, 'examples_csu'):
    print(f'  [FAIL] sbom_csu missing: examples_csu'); failed += 1
else:
    print(f'  [PASS] sbom_csu has: examples_csu')

sys.exit(failed)
"
