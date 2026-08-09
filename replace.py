import re
import os

files_map = {
    'lib/features/courses/presentation/courses_screen.dart': ('AiCoursesAssistantSheet', 'courses'),
    'lib/features/cycle/presentation/cycle_screen.dart': ('AiCycleAssistantSheet', 'cycle'),
    'lib/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart': ('AiCycleAssistantSheet', 'cycle'),
    'lib/features/cycle/presentation/widgets/cycle_sos_section.dart': ('AiCycleAssistantSheet', 'cycle'),
    'lib/features/goals/presentation/goals_screen.dart': ('AiGoalsAssistantSheet', 'goals'),
    'lib/features/health/presentation/health_screen.dart': ('AiHealthAssistantSheet', 'health'),
    'lib/features/konkur/presentation/konkur_screen.dart': ('AiKonkurAssistantSheet', 'konkur'),
    'lib/features/wellbeing/presentation/wellbeing_screen.dart': ('AiWellbeingAssistantSheet', 'wellbeing'),
    'lib/features/worship/presentation/worship_screen.dart': ('AiWorshipAssistantSheet', 'worship')
}

def replace_balanced(text, class_name, persona_id):
    start = 0
    while True:
        idx = text.find(class_name + '(', start)
        if idx == -1:
            break
        
        # Find matching closing parenthesis
        count = 0
        end_idx = -1
        for i in range(idx + len(class_name), len(text)):
            if text[i] == '(':
                count += 1
            elif text[i] == ')':
                count -= 1
                if count == 0:
                    end_idx = i
                    break
        
        if end_idx != -1:
            replacement = f"AssistantSheet(persona: PersonaRegistry.instance.getPersona('{persona_id}')!)"
            text = text[:idx] + replacement + text[end_idx+1:]
            start = idx + len(replacement)
        else:
            start = idx + 1
            
    return text

for fpath, (cname, pid) in files_map.items():
    if not os.path.exists(fpath): continue
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove old imports
    content = re.sub(r'import .*/ai_.*_assistant_sheet\.dart.*;\n', '', content)
    
    # Add new imports if not exist
    if 'persona_registry.dart' not in content:
        content = "import 'package:ritmo/core/domain/personas/persona_registry.dart';\n" + content
    if 'unified_assistant_sheet.dart' not in content:
        content = "import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';\n" + content
        
    content = replace_balanced(content, cname, pid)
    
    with open(fpath, 'w', encoding='utf-8') as f:
        f.write(content)
