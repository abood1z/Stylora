
import docx
import re

def unify_figures(path):
    doc = docx.Document(path)
    count = 0
    # Pattern: Figure X.X followed by something that isn't a colon
    pattern = re.compile(r"(Figure \d+\.\d+)(?![:])(\s+)")
    
    for para in doc.paragraphs:
        if "Figure" in para.text:
            new_text = pattern.sub(r"\1:\2", para.text)
            if new_text != para.text:
                para.text = new_text
                count += 1
    
    doc.save(path)
    print(f"Unified {count} figure labels.")

if __name__ == "__main__":
    unify_figures(r"d:\project_folder\documentationstylora_corrected.docx")
