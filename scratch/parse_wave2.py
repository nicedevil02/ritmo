with open(r"C:\Users\bahman\.gemini\antigravity\brain\5b860167-e2a3-40f9-a1a1-937f2052a03f\scratch\wave2_prompt.txt", "r", encoding="utf-8") as f:
    text = f.read()

# find where "موج ۲" starts and where "موج ۳" starts
m2_pos = text.find("موج ۲")
m3_pos = text.find("موج ۳")

print(f"M2 pos: {m2_pos}, M3 pos: {m3_pos}")

with open(r"C:\Users\bahman\.gemini\antigravity\brain\5b860167-e2a3-40f9-a1a1-937f2052a03f\scratch\wave2_exact.txt", "w", encoding="utf-8") as out:
    out.write(text[m2_pos:m3_pos if m3_pos != -1 else len(text)])

print("Extracted wave2_exact.txt")
