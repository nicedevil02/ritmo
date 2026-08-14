import os
import re

dir_path = r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\lib\features\calendar'
theme_import = "import 'package:ritmo/core/theme/ritmo_theme.dart';"
haptics_import = "import 'package:ritmo/core/ux/ritmo_haptics.dart';"

for root, dirs, files in os.walk(dir_path):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            new_content = content

            # Remove dead imports
            new_content = re.sub(r"import\s+['\"][^'\"]*calendar_tokens\.dart['\"];?\n?", '', new_content)
            new_content = re.sub(r"import\s+['\"][^'\"]*calendar_motion\.dart['\"];?\n?", '', new_content)

            # Replace any remaining CalendarMotion
            new_content = re.sub(r'CalendarMotion\.', 'RitmoMotion.', new_content)

            # Check if RitmoSpacing / RitmoRadius / RitmoMotion / context.colors / RitmoColors / RitmoTheme is used
            uses_theme = any(k in new_content for k in ['RitmoSpacing', 'RitmoRadius', 'RitmoMotion', 'context.colors', 'RitmoTheme', 'RitmoColors'])
            if uses_theme and theme_import not in new_content:
                if 'import ' in new_content:
                    first_import_pos = new_content.find('import ')
                    semicolon_pos = new_content.find(';\n', first_import_pos)
                    if semicolon_pos != -1:
                        new_content = new_content[:semicolon_pos + 2] + theme_import + '\n' + new_content[semicolon_pos + 2:]
                    else:
                        new_content = theme_import + '\n' + new_content
                else:
                    new_content = theme_import + '\n' + new_content

            # Check if RitmoHapticsPolicy is used
            uses_haptics = 'RitmoHapticsPolicy' in new_content or 'RitmoHaptics' in new_content
            if uses_haptics and haptics_import not in new_content:
                if 'import ' in new_content:
                    first_import_pos = new_content.find('import ')
                    semicolon_pos = new_content.find(';\n', first_import_pos)
                    if semicolon_pos != -1:
                        new_content = new_content[:semicolon_pos + 2] + haptics_import + '\n' + new_content[semicolon_pos + 2:]
                    else:
                        new_content = haptics_import + '\n' + new_content
                else:
                    new_content = haptics_import + '\n' + new_content

            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f'Updated {file}')
