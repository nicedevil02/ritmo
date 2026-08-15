with open(r"C:\Users\bahman\.gemini\antigravity\brain\5b860167-e2a3-40f9-a1a1-937f2052a03f\scratch\wave2_prompt.txt", "r", encoding="utf-8") as f:
    text = f.read()

import re
matches = [m.start() for m in re.finditer(r'#+\s*موج\s*[۱-۳1-3]', text)]
print("Header matches at:", matches)
for pos in matches:
    print("--- SNIPPET ---")
    print(text[pos:pos+200])

# Also search for M2-
m2_matches = [m.start() for m in re.finditer(r'M2-[A-Z0-9]', text)]
print("M2 items at:", len(m2_matches))
