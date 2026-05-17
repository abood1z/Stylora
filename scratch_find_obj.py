
import docx

def find_objectives(file_path):
    doc = docx.Document(file_path)
    for i, para in enumerate(doc.paragraphs):
        if "Enhance Wardrobe Sustainability" in para.text:
            print(f"[{i}] {para.text}")

if __name__ == "__main__":
    find_objectives(r"d:\project_folder\documentationstylora.docx")
