"""Audit the exact publish archive, without uploading or reading credentials."""
from pathlib import Path
import hashlib, json, subprocess, zipfile, re
root = Path(__file__).resolve().parent.parent
subprocess.run(['moon', 'package'], cwd=root, check=True)
version = re.search(r'^version\s*=\s*"([^"]+)"', (root / 'moon.mod').read_text(), re.M)[1]
archive = root / f'_build/publish/YeeHh2004-mooninput-{version}.zip'
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    names = set(z.namelist())
    required = {'moon.mod', 'moon.pkg', 'pkg.generated.mbti', 'editor.mbt', 'pattern.mbt',
                'decimal.mbt', 'date.mbt', 'LICENSE', 'README.md', 'NOTICE.md',
                'examples/basic/main.mbt', 'examples/rules/main.mbt', 'protocol/process.mbt', 'docs/BEHAVIOR.md',
                'engine_rules.mbt', 'regex_mask.mbt', 'localized.mbt', 'presentation.mbt', 'snapshot.mbt',
                'acceptance_core_test.mbt', 'acceptance_numeric_regex_test.mbt', 'docs/IMASK-COVERAGE.md'}
    assert required <= names, f'Missing files: {required - names}'
    for name in names:
        p = Path(name)
        assert not p.is_absolute() and '..' not in p.parts
        assert not any(x in {'.git', '.moon', '.mooncakes', 'node_modules', '_build', 'dist'} for x in p.parts)
        assert p.name != 'credentials.json'
        assert not name.startswith(('web/', 'scripts/', 'tests/', 'bridge/', 'cli/', 'examples/consumer/'))
        assert p.suffix not in {'.mjs', '.js', '.py', '.zip'}
    assert 'license = "MIT"' in z.read('moon.mod').decode()
print(json.dumps({'files': len(names), 'bytes': archive.stat().st_size,
                  'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}, indent=2))
