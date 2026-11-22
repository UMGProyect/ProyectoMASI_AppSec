#!/usr/bin/env python3
"""SCA de dependencias CDN: conserva avisos OSV y clasifica su aplicabilidad.

Uso: python3 .github/scripts/sca_cdn.py [--fail-on-vuln] [--no-network]
"""
import json, os, pathlib, re, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
FAIL = '--fail-on-vuln' in sys.argv
OFFLINE = '--no-network' in sys.argv
SOURCES = [ROOT / 'index.html', *sorted((ROOT / 'js').glob('*.js'))]
PATTERNS = [
    re.compile(r'cdn\.jsdelivr\.net/npm/((?:@[\w.-]+/)?[\w.-]+)@(\d[\w.+-]*)'),
    re.compile(r'cdnjs\.cloudflare\.com/ajax/libs/([\w.-]+)/(\d[\w.+-]*)/'),
    re.compile(r'cdn\.sheetjs\.com/(xlsx)-(\d[\d.]*)/'),
]
URL_RE = re.compile(r'https://[\w.-]+/[^\s\'"`)>]+')
SHEETJS_OFFICIAL_URL = 'https://cdn.sheetjs.com/xlsx-0.20.3/package/dist/xlsx.full.min.js'
SHEETJS_FIXED_ADVISORIES = {
    'GHSA-4r6h-8v6p-xvw6': 'https://github.com/advisories/GHSA-4r6h-8v6p-xvw6',
    'GHSA-5pgg-2g8v-p4x9': 'https://github.com/advisories/GHSA-5pgg-2g8v-p4x9',
}


def find_deps():
    deps = {}
    for f in SOURCES:
        text = f.read_text(encoding='utf-8', errors='replace')
        for pat in PATTERNS:
            for name, ver in pat.findall(text):
                deps.setdefault((name, ver), set()).add(str(f.relative_to(ROOT)))
    return deps


def find_no_sri():
    out = []
    html = (ROOT / 'index.html').read_text(encoding='utf-8', errors='replace')
    for tag in re.findall(r'<script\b[^>]*>', html, re.I):
        m = re.search(r'src="(https?://[^"]+)"', tag)
        if m and 'integrity=' not in tag:
            out.append({'url': m.group(1), 'where': 'index.html (etiqueta script)'})
    for f in sorted((ROOT / 'js').glob('*.js')):
        text = f.read_text(encoding='utf-8', errors='replace')
        for u in set(URL_RE.findall(text)):
            if re.search(r'(cdn\.|cdnjs|jsdelivr|sheetjs|unpkg)', u):
                out.append({'url': u, 'where': f'{f.relative_to(ROOT)} (carga dinámica o import)'})
    return out


def osv(path, payload=None):
    req = urllib.request.Request(
        'https://api.osv.dev' + path,
        data=json.dumps(payload).encode() if payload else None,
        headers={'Content-Type': 'application/json'},
        method='POST' if payload else 'GET')
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def is_official_sheetjs_0203(name, version, files):
    """Sólo reconoce la ruta oficial exacta; evita extrapolar a npm/otros CDN."""
    if (name, version) != ('xlsx', '0.20.3'):
        return False
    origins = set()
    for f in files:
        content = (ROOT / f).read_text(encoding='utf-8', errors='replace')
        origins.update(re.findall(r'https://[^\s\'"`)>]+/xlsx-0\.20\.3/[^\s\'"`)>]+', content))
    return origins == {SHEETJS_OFFICIAL_URL}


def classify_advisory(advisory, is_official):
    """Conserva el objeto OSV y añade estado motivado sin alterar el original."""
    result = dict(advisory)
    if is_official and advisory['id'] in SHEETJS_FIXED_ADVISORIES:
        result.update({
            'aplicabilidad': 'no_aplicable',
            'justificacion': 'SheetJS 0.20.3 del CDN oficial está por encima de las versiones afectadas según el advisory.',
            'referencia_evaluacion': SHEETJS_FIXED_ADVISORIES[advisory['id']],
        })
    else:
        result['aplicabilidad'] = 'aplicable_o_pendiente_revision'
    return result


def main():
    deps = find_deps()
    report = {'dependencias': [], 'sin_sri': find_no_sri()}
    total_applicable = 0
    errors = 0
    for (name, ver), files in sorted(deps.items()):
        entry = {'paquete': name, 'version': ver, 'archivos': sorted(files),
                 'vulnerabilidades': [], 'avisos_no_aplicables': []}
        is_official = is_official_sheetjs_0203(name, ver, files)
        if not OFFLINE:
            try:
                res = osv('/v1/query', {'package': {'name': name, 'ecosystem': 'npm'}, 'version': ver})
                for v in res.get('vulns', []):
                    d = osv('/v1/vulns/' + v['id'])
                    raw_advisory = {
                        'id': d.get('id'),
                        'alias': [a for a in d.get('aliases', []) if a.startswith('CVE-')],
                        'resumen': d.get('summary', ''),
                        'severidad': (d.get('database_specific') or {}).get('severity', 'sin dato'),
                    }
                    classified = classify_advisory(raw_advisory, is_official)
                    if classified['aplicabilidad'] == 'no_aplicable':
                        entry['avisos_no_aplicables'].append(classified)
                    else:
                        entry['vulnerabilidades'].append(classified)
            except Exception as e:
                entry['error'] = str(e)
                errors += 1
        total_applicable += len(entry['vulnerabilidades'])
        report['dependencias'].append(entry)

    (ROOT / 'sca-report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    lines = ['## SCA: dependencias cargadas por CDN', '',
             '| Paquete | Versión | Vulnerabilidades | Avisos no aplicables | Detalle |',
             '| --- | --- | --- | --- | --- |']
    for e in report['dependencias']:
        det = '; '.join(f"{v['id']} ({v['severidad']})" for v in e['vulnerabilidades']) or ('error: ' + e['error'] if 'error' in e else '-')
        n = 'n/d' if 'error' in e else len(e['vulnerabilidades'])
        lines.append(f"| {e['paquete']} | {e['version']} | {n} | {len(e['avisos_no_aplicables'])} | {det} |")
    lines += ['', f"## Scripts externos sin SRI: {len(report['sin_sri'])}", '']
    lines += [f"- `{s['url']}` ({s['where']})" for s in report['sin_sri']]
    if errors:
        lines += ['', f'**ERROR:** {errors} consultas OSV fallaron; el análisis es incompleto.']
    md = '\n'.join(lines)
    print(md)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as fh:
            fh.write(md + '\n')
    if errors:
        sys.exit(2)
    if FAIL and total_applicable:
        sys.exit(1)


if __name__ == '__main__':
    main()
