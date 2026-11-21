#!/usr/bin/env python3
"""SCA para dependencias cargadas por CDN (el proyecto no usa npm para el frontend).

1. Extrae paquete@versión de index.html y js/*.js (jsDelivr, cdnjs, SheetJS).
2. Consulta la base OSV (api.osv.dev) y lista las vulnerabilidades conocidas.
3. Señala los scripts externos que se cargan sin SRI (atributo integrity).

Uso:  python3 .github/scripts/sca_cdn.py [--fail-on-vuln] [--no-network]
Salida: sca-report.json y, en GitHub Actions, un resumen en el panel de la ejecución.
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


def find_deps():
    deps = {}
    for f in SOURCES:
        text = f.read_text(encoding='utf-8', errors='replace')
        for pat in PATTERNS:
            for name, ver in pat.findall(text):
                deps.setdefault((name, ver), set()).add(str(f.relative_to(ROOT)))
    return deps


def find_no_sri():
    """Scripts de index.html con origen externo y sin integrity, más cargas dinámicas en js/."""
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


def main():
    deps = find_deps()
    report = {'dependencias': [], 'sin_sri': find_no_sri()}
    total = 0
    for (name, ver), files in sorted(deps.items()):
        entry = {'paquete': name, 'version': ver, 'archivos': sorted(files), 'vulnerabilidades': []}
        if not OFFLINE:
            try:
                res = osv('/v1/query', {'package': {'name': name, 'ecosystem': 'npm'}, 'version': ver})
                for v in res.get('vulns', []):
                    d = osv('/v1/vulns/' + v['id'])
                    entry['vulnerabilidades'].append({
                        'id': d.get('id'),
                        'alias': [a for a in d.get('aliases', []) if a.startswith('CVE-')],
                        'resumen': d.get('summary', ''),
                        'severidad': (d.get('database_specific') or {}).get('severity', 'sin dato'),
                    })
            except Exception as e:  # una caída de OSV no debe ocultar el resto del reporte
                entry['error'] = str(e)
        total += len(entry['vulnerabilidades'])
        report['dependencias'].append(entry)

    (ROOT / 'sca-report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')

    lines = ['## SCA: dependencias cargadas por CDN', '',
             '| Paquete | Versión | Vulnerabilidades | Detalle |', '| --- | --- | --- | --- |']
    for e in report['dependencias']:
        det = '; '.join(f"{v['id']} ({v['severidad']})" for v in e['vulnerabilidades']) or ('error: ' + e['error'] if 'error' in e else '-')
        n = 'n/d' if 'error' in e else len(e['vulnerabilidades'])
        lines.append(f"| {e['paquete']} | {e['version']} | {n} | {det} |")
    lines += ['', f"## Scripts externos sin SRI: {len(report['sin_sri'])}", '']
    lines += [f"- `{s['url']}` ({s['where']})" for s in report['sin_sri']]
    md = '\n'.join(lines)
    print(md)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as fh:
            fh.write(md + '\n')
    if FAIL and total:
        sys.exit(1)


if __name__ == '__main__':
    main()
