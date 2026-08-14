import os
import re

files = [
    r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\lib\features\calendar\presentation\journey_controller.dart',
    r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\lib\features\calendar\presentation\widgets\day_review_sheet.dart',
    r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\lib\features\calendar\presentation\widgets\empty_day_view.dart',
    r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\lib\features\calendar\presentation\widgets\now_pill.dart',
    r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\lib\features\calendar\presentation\widgets\timeline_grid.dart',
]

for p in files:
    with open(p, 'r', encoding='utf-8') as f:
        c = f.read()
    c2 = re.sub(r"import 'package:ritmo/core/ux/ritmo_haptics\.dart';\n?", '', c)
    if c2 != c:
        with open(p, 'w', encoding='utf-8') as f:
            f.write(c2)
        print(f'Removed unused haptics import from {os.path.basename(p)}')
