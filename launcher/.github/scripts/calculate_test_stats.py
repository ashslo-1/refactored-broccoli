import json
import os

if os.path.exists('test-reports/results.json'):
    success = 0
    failed = 0
    with open('test-reports/results.json') as f:
        for line in f:
            try:
                data = json.loads(line)
                if data.get('type') == 'testDone':
                    if data.get('hidden', False):
                        continue
                    res = data.get('result')
                    if res == 'success':
                        success += 1
                    elif res in ('failure', 'error'):
                        failed += 1
            except Exception:
                pass
    total = success + failed
    if failed > 0:
        summary = f'{success}/{total} passed'
        color = 'red'
    else:
        summary = f'{success} passed'
        color = 'green'
else:
    summary = 'no tests'
    color = 'grey'

github_output = os.environ.get('GITHUB_OUTPUT')
if github_output:
    with open(github_output, 'a') as f:
        f.write(f'summary={summary}\n')
        f.write(f'color={color}\n')
