
import docx

def list_headings(file_path):
    doc = docx.Document(file_path)
    for i, para in enumerate(doc.paragraphs):
        if "CHAPTER" in para.text.upper() or any(x in para.text for x in ["4.1", "4.2", "3.1"]):
            print(f"[{i}] {para.text}")

if __name__ == "__main__":
    list_headings(r"d:\project_folder\documentationstylora_corrected.docx")
