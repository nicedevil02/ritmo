with open(r"C:\Users\bahman\.gemini\antigravity\brain\5b860167-e2a3-40f9-a1a1-937f2052a03f\scratch\wave2_prompt.txt", "r", encoding="utf-8") as f:
    text = f.read()

import re
m2_first = text.find("M2-A")
if m2_first == -1:
    m2_first = text.find("M2-1")

# Find the heading before M2-A
heading_pos = text.rfind("#", 0, m2_first)
heading_pos = text.rfind("\n#", 0, heading_pos)

m3_pos = text.find("M3-A")
if m3_pos == -1:
    m3_pos = text.find("M3-1")
m3_heading = text.rfind("\n#", 0, m3_pos)

wave2_text = text[heading_pos:m3_heading]
with open(r"C:\Users\bahman\.gemini\antigravity\brain\5b860167-e2a3-40f9-a1a1-937f2052a03f\scratch\wave2_full.md", "w", encoding="utf-8") as out:
    out.write(wave2_text)

print(f"Extracted Wave 2 ({len(wave2_text)} chars) to scratch/wave2_full.md")
