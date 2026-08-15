import json

transcript_path = r"C:\Users\bahman\.gemini\antigravity\brain\5b860167-e2a3-40f9-a1a1-937f2052a03f\.system_generated\logs\transcript_full.jsonl"

with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        obj = json.loads(line)
        content = obj.get("content", "")
        if "امواج ۱ تا ۳" in content or "موج ۲" in content:
            # Look for the full user prompt containing Wave 2
            if "## موج ۲" in content or "موج ۲:" in content or "Phase M2" in content or "M2-" in content:
                print(f"Found step {obj.get('step_index')}")
                with open(r"C:\Users\bahman\.gemini\antigravity\brain\5b860167-e2a3-40f9-a1a1-937f2052a03f\scratch\wave2_prompt.txt", "w", encoding="utf-8") as out:
                    out.write(content)
                break
print("Done")
