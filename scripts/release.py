"""Package a clean, built revision with offline runnable assets and checksums."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
def git(*args):
    return subprocess.check_output(['git', *args], cwd=root).decode().strip()

assert not git('status', '--porcelain'), 'Commit changes before packaging a release'
info = json.loads((root / 'web/build-info.json').read_text())
assert info['sourceCommit'] == git('rev-parse', 'HEAD'), 'Run scripts/build.mjs at HEAD'
assert info['engineSha256'] == hashlib.sha256((root / 'web/mooninput.mjs').read_bytes()).hexdigest()
version = info['version']
names = set(git('ls-files').splitlines())
names.update(['web/mooninput.mjs', 'web/build-info.json', 'web/LICENSE.txt', 'web/THIRD-PARTY-NOTICES.txt'])
data = {name: (root / name).read_bytes() for name in sorted(names)}
data['FILES.sha256'] = ''.join(f'{hashlib.sha256(content).hexdigest()}  {name}\n' for name, content in data.items()).encode()
out = root / 'dist'
out.mkdir(exist_ok=True)
archive = out / f'mooninput-{version}.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for name, content in sorted(data.items()):
        entry = zipfile.ZipInfo(f'mooninput-{version}/{name}', date_time=(1980, 1, 1, 0, 0, 0))
        entry.compress_type = zipfile.ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        z.writestr(entry, content)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
checksum = f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n'
(out / 'SHA256SUMS.txt').write_text(checksum, encoding='utf-8')
print(f'Packaged {len(data)} files, {archive.stat().st_size} bytes\n{checksum}')
