import urllib.request
import json
import os
import subprocess

REPO = 'leanbitlab-org/LtvLauncher'
token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')

headers = {'User-Agent': 'Mozilla/5.0'}
if token:
    headers['Authorization'] = f'token {token}'

stars = 0
version = 'unknown'
downloads = 0

# Try gh CLI first (paginated)
gh_success = False
try:
    res_stars = subprocess.run(
        ['gh', 'api', f'repos/{REPO}', '--jq', '.stargazers_count'],
        capture_output=True, text=True, check=True
    )
    stars = int(res_stars.stdout.strip() or 0)

    res_ver = subprocess.run(
        ['gh', 'api', f'repos/{REPO}/releases?per_page=1', '--jq', '.[0].tag_name'],
        capture_output=True, text=True, check=True
    )
    version = res_ver.stdout.strip() or 'unknown'

    res_dl = subprocess.run(
        ['gh', 'api', f'repos/{REPO}/releases', '--paginate', '--jq', '.[] | .assets[]?.download_count'],
        capture_output=True, text=True, check=True
    )
    dl_counts = [int(val) for val in res_dl.stdout.strip().splitlines() if val.isdigit()]
    downloads = sum(dl_counts)
    gh_success = True
except Exception as e:
    print(f'gh CLI fetch skipped/failed: {e}')

if not gh_success:
    # Fetch Stars via urllib
    try:
        req_repo = urllib.request.Request(f'https://api.github.com/repos/{REPO}', headers=headers)
        with urllib.request.urlopen(req_repo) as response:
            repo_data = json.loads(response.read().decode())
            stars = repo_data.get('stargazers_count', 0)
    except Exception as e:
        print(f'Error fetching stars: {e}')
        stars = 0

    # Fetch Releases & Downloads with pagination via urllib
    downloads = 0
    version = 'unknown'
    page = 1
    while True:
        try:
            req_releases = urllib.request.Request(
                f'https://api.github.com/repos/{REPO}/releases?per_page=100&page={page}',
                headers=headers
            )
            with urllib.request.urlopen(req_releases) as response:
                releases_data = json.loads(response.read().decode())
                if not releases_data:
                    break
                if page == 1 and releases_data:
                    version = releases_data[0].get('tag_name', 'unknown')
                for release in releases_data:
                    for asset in release.get('assets', []):
                        downloads += asset.get('download_count', 0)
                if len(releases_data) < 100:
                    break
                page += 1
        except Exception as e:
            print(f'Error fetching releases page {page}: {e}')
            break

def format_num(n):
    if n >= 1000000:
        return f'{n/1000000:.1f}M'
    if n >= 1000:
        return f'{n/1000:.1f}k'
    return str(n)

stars_str = format_num(stars)
downloads_str = format_num(downloads)

print(f'Stars: {stars_str} ({stars}), Version: {version}, Downloads: {downloads_str} ({downloads})')

github_output = os.environ.get('GITHUB_OUTPUT')
if github_output:
    with open(github_output, 'a') as f:
        f.write(f'stars={stars_str}\n')
        f.write(f'version={version}\n')
        f.write(f'downloads={downloads_str}\n')

