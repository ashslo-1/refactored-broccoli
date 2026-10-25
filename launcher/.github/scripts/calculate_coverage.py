import os

if os.path.exists('coverage/lcov.info'):
    lf = 0
    lh = 0
    with open('coverage/lcov.info') as f:
        for line in f:
            if line.startswith('LF:'):
                lf += int(line.split(':')[1])
            elif line.startswith('LH:'):
                lh += int(line.split(':')[1])
    percentage = (lh / lf) * 100 if lf > 0 else 0.0
else:
    percentage = 0.0

percentage_str = f"{percentage:.1f}"

# Color logic
if percentage >= 90:
    color = 'green'
elif percentage >= 75:
    color = 'yellowgreen'
elif percentage >= 50:
    color = 'yellow'
else:
    color = 'red'

github_output = os.environ.get('GITHUB_OUTPUT')
if github_output:
    with open(github_output, 'a') as f:
        f.write(f'percent={percentage_str}\n')
        f.write(f'color={color}\n')
